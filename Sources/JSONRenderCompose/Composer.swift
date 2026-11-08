public import JSONRenderCore

/// Catalog-constrained composition on a decision evaluator (upstream batched
/// `experimental_composeSpec`, with the OpenAI Decisions API in place of a Jev model).
///
/// The evaluator picks, places and orders app-supplied candidates. It never writes prose or
/// data, never sees element props, bindings or state, and never runs an action. Two
/// requests at most: selection (root, membership, density), then layout (parents, order).
/// The first preview is published after the selection round.
public struct Composer: Sendable {
    public let catalog: Catalog
    public let candidates: [CompositionCandidate]
    public let evaluator: any DecisionEvaluator
    public let limits: ComposeLimits
    public let instructions: ComposeInstructions
    let groups: [CandidateGroup]

    /// Checks the limits and every candidate. A bad candidate fails here, before any
    /// request.
    public init(
        catalog: Catalog, candidates: [CompositionCandidate], evaluator: any DecisionEvaluator,
        limits: ComposeLimits = .default, instructions: ComposeInstructions = .init()
    ) throws(CompositionError) {
        for (name, value) in [
            ("maxElements", limits.maxElements), ("maxDepth", limits.maxDepth),
            ("maxRounds", limits.maxRounds),
            ("maxQuestionsPerRequest", limits.maxQuestionsPerRequest),
        ] where value < 1 {
            throw .invalidLimits("\(name) must be at least one.")
        }
        guard limits.densityBudget.count == QuestionBuilder.densityLevels.count,
            limits.densityBudget.allSatisfy({ $0 >= 1 })
        else {
            throw .invalidLimits("densityBudget must hold three values of at least one.")
        }
        try CandidateValidation.check(candidates, catalog: catalog)
        self.catalog = catalog
        self.candidates = candidates
        self.evaluator = evaluator
        self.limits = limits
        self.instructions = instructions
        self.groups = QuestionBuilder.groups(candidates, limits: limits)
    }

    /// Composes a spec for `prompt`.
    ///
    /// - Parameters:
    ///   - context: app context shared with the evaluator on purpose. Put only what the
    ///     evaluator may read; never secrets, file contents or terminal text by accident.
    ///   - initialState: goes into the spec's `state`; never sent to the evaluator.
    /// - Returns: a pull-based stream: each request runs when the consumer asks for the
    ///   next event, so a consumer that stops after the first `.step` causes no layout
    ///   request. Cancelling the consuming task cancels the request in flight. The stream
    ///   throws `CompositionError.evaluator(.tooManyQuestions)` before any request when the
    ///   selection round is over the cap, and `CancellationError` on cancellation. Evaluator
    ///   failures do not throw: they end in `.complete` with `.unavailable`.
    public func compose(prompt: String, context: JSONValue? = nil, initialState: JSONValue? = nil)
        -> AsyncThrowingStream<ComposeEvent, any Error>
    {
        let run = ComposeRun(
            composer: self, prompt: prompt, context: context,
            state: initialState ?? .object([:]))
        return AsyncThrowingStream { try await run.next() }
    }
}

/// The state of one composition. An actor, so the stream's `@Sendable` produce closure can
/// own mutable progress without `@unchecked Sendable`.
actor ComposeRun {
    private enum Stage {
        case select
        case layout(selected: [CompositionCandidate], preview: Spec)
        case done
    }

    private let composer: Composer
    private let prompt: String
    private let context: JSONValue?
    private let state: JSONValue
    private let clock = ContinuousClock()
    private let started: ContinuousClock.Instant
    private var stage = Stage.select
    private var pending: [ComposeEvent] = []
    private var steps: [ComposeStep] = []
    private var inputTokens: Int? = 0

    init(composer: Composer, prompt: String, context: JSONValue?, state: JSONValue) {
        self.composer = composer
        self.prompt = prompt
        self.context = context
        self.state = state
        self.started = clock.now
    }

    func next() async throws -> ComposeEvent? {
        if pending.isEmpty {
            let current = stage
            stage = .done
            do {
                switch current {
                case .select: try await selectRound()
                case .layout(let selected, let preview):
                    try await layoutRound(selected: selected, preview: preview)
                case .done: break
                }
            } catch {
                stage = .done
                pending = []
                throw error
            }
        }
        return pending.isEmpty ? nil : pending.removeFirst()
    }

    // MARK: Rounds

    private func selectRound() async throws {
        let limits = composer.limits
        let catalog = composer.catalog
        let plan = QuestionBuilder.selection(
            candidates: composer.candidates, groups: composer.groups, prompt: prompt,
            context: context, instructions: composer.instructions)
        let cap = min(limits.maxQuestionsPerRequest, ComposeLimits.apiQuestionCap)
        guard plan.questions.count <= cap else {
            throw CompositionError.evaluator(.tooManyQuestions(plan.questions.count))
        }
        let description = "Select catalog elements in one request"
        guard
            let (response, elapsed) = try await request(
                plan.input, plan.questions, .select, description)
        else {
            finish(nil, .unavailable)
            return
        }
        let answers = Dictionary(
            response.answers.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var reader = AnswerReader(limits: limits)

        // Root: an accepted "unavailable" stops; a refusal or low confidence falls back to
        // the first root-eligible candidate in catalog order.
        let rootCandidates = composer.candidates.filter(\.root)
        let offered = Set(rootCandidates.map(\.id) + [QuestionBuilder.unavailable])
        let rootValue = answers["root"].flatMap { reader.choice($0, offered: offered) }
        if rootValue == QuestionBuilder.unavailable {
            record(.select, description, elapsed, response, reader.notes)
            finish(nil, .unavailable)
            return
        }
        guard
            let root = rootCandidates.first(where: { $0.id == rootValue }) ?? rootCandidates.first
        else {
            record(.select, description, elapsed, response, reader.notes)
            finish(nil, .unavailable)
            return
        }

        let level = answers[QuestionBuilder.density].map {
            reader.densityLevel($0, levels: QuestionBuilder.densityLevels.count)
        }
        let budget = min(limits.densityBudget[level ?? 1], limits.maxElements)
        var selection = CompositionApply.select(
            root: root, groups: composer.groups, answers: answers, reader: &reader,
            budget: budget, catalog: catalog, limits: limits)

        var preview = CompositionApply.preview(selection.selected, catalog: catalog, state: state)
        var note = ""
        if CompositionTree.problem(preview, catalog: catalog, maxDepth: limits.maxDepth) != nil {
            // Drop the elements the validator names and try once more. The root cannot go.
            let offending = CompositionTree.offendingIDs(preview, catalog: catalog)
            let kept = selection.selected.enumerated().filter { index, _ in
                index == 0 || !offending.contains("node_\(index)")
            }.map(\.element)
            preview = CompositionApply.preview(kept, catalog: catalog, state: state)
            if offending.contains("node_0") || kept.count == selection.selected.count
                || CompositionTree.problem(preview, catalog: catalog, maxDepth: limits.maxDepth)
                    != nil
            {
                record(
                    .select, description + "; preview rejected", elapsed, response, reader.notes)
                finish(nil, .unavailable)
                return
            }
            note = "; dropped \(selection.selected.count - kept.count) invalid elements"
            selection.selected = kept
        }
        let step = record(
            .select, description + note, elapsed, response, reader.notes,
            warnings: CompositionTree.warningCount(preview, catalog: catalog))
        pending.append(.step(spec: preview, step: step))

        let rootSlots = catalog.component(named: root.element.type)?.slots ?? []
        let count = selection.selected.count
        if selection.limited {
            finish(preview, .limit)
        } else if count == 1 || (count == 2 && rootSlots.count == 1) {
            finish(preview, .finish)
        } else if limits.maxRounds < 2 {
            finish(preview, .limit)
        } else {
            stage = .layout(selected: selection.selected, preview: preview)
        }
    }

    private func layoutRound(selected: [CompositionCandidate], preview: Spec) async throws {
        let limits = composer.limits
        let catalog = composer.catalog
        let plan = QuestionBuilder.layout(
            selected: selected, catalog: catalog, prompt: prompt, context: context,
            limits: limits, instructions: composer.instructions)
        let cap = min(limits.maxQuestionsPerRequest, ComposeLimits.apiQuestionCap)
        guard plan.questions.count <= cap else {
            finish(preview, .limit)
            return
        }
        let description = "Arrange selected elements in one request"
        guard
            let (response, elapsed) = try await request(
                plan.input, plan.questions, .layout, description)
        else {
            finish(preview, .unavailable)
            return
        }
        let answers = Dictionary(
            response.answers.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var reader = AnswerReader(limits: limits)
        guard let slot = CompositionApply.defaultSlot(of: selected[0], catalog: catalog) else {
            finish(preview, .limit)
            return
        }
        let next = CompositionApply.layout(
            preview: preview, plan: plan, answers: answers, reader: &reader,
            rootDefault: Attachment(id: "node_0", slot: slot))
        if let problem = CompositionTree.problem(next, catalog: catalog, maxDepth: limits.maxDepth)
        {
            record(
                .layout, description + "; layout rejected: \(problem)", elapsed, response,
                reader.notes)
            finish(preview, .limit)
            return
        }
        let step = record(
            .layout, description, elapsed, response, reader.notes,
            warnings: CompositionTree.warningCount(next, catalog: catalog))
        pending.append(.step(spec: next, step: step))
        finish(next, .finish)
    }

    // MARK: Helpers

    /// One evaluator request. Returns `nil` after recording a failed step; rethrows
    /// cancellation.
    private func request(
        _ input: DecisionInput, _ questions: [DecisionQuestion], _ phase: ComposeStep.Phase,
        _ description: String
    ) async throws -> (DecisionResponse, Duration)? {
        try Task.checkCancellation()
        let callStarted = clock.now
        let response: DecisionResponse
        do {
            response = try await composer.evaluator.decide(input: input, questions: questions)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            fail(phase, description, callStarted, code: Self.code(error))
            return nil
        }
        try Task.checkCancellation()
        if let problem = DecisionsWire.shapeProblem(response, questions: questions) {
            let error = CompositionError.invalidAnswer(
                question: problem.question, reason: problem.reason)
            fail(phase, description, callStarted, code: "\(error)")
            return nil
        }
        if let tokens = inputTokens, let used = response.usage?.inputTokens {
            inputTokens = tokens + used
        } else {
            inputTokens = nil
        }
        return (response, clock.now - callStarted)
    }

    /// A short code for a step description. Never an error's free text from outside.
    private static func code(_ error: any Error) -> String {
        if let error = error as? DecisionError { return "\(error)" }
        return "failed"
    }

    private func fail(
        _ phase: ComposeStep.Phase, _ description: String, _ callStarted: ContinuousClock.Instant,
        code: String
    ) {
        steps.append(
            ComposeStep(
                index: steps.count, phase: phase, description: "\(description); evaluator: \(code)",
                elapsed: clock.now - callStarted, inputTokens: nil, answers: []))
    }

    @discardableResult
    private func record(
        _ phase: ComposeStep.Phase, _ description: String, _ elapsed: Duration,
        _ response: DecisionResponse, _ notes: AnswerNotes, warnings: Int = 0
    ) -> ComposeStep {
        let step = ComposeStep(
            index: steps.count, phase: phase, description: description, elapsed: elapsed,
            inputTokens: response.usage?.inputTokens, answers: response.answers,
            refused: notes.refused, fallbacks: notes.fallbacks, validationWarnings: warnings)
        steps.append(step)
        return step
    }

    private func finish(_ spec: Spec?, _ reason: ComposeStopReason) {
        pending.append(
            .complete(
                spec: spec, steps: steps, elapsed: clock.now - started, inputTokens: inputTokens,
                stopReason: reason))
        stage = .done
    }
}
