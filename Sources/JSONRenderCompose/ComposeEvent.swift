public import JSONRenderCore

/// One evaluator request and what the composer did with its answers.
public struct ComposeStep: Sendable, Hashable {
    public enum Phase: String, Sendable, Hashable {
        /// Round 1: root, membership and density.
        case select
        /// Round 2: parents and sibling order.
        case layout
        /// Reserved for composition edits (a later release).
        case edit
    }

    public var index: Int
    public var phase: Phase
    /// A fixed text for the round. After a failure or a rejected layout it ends with a code,
    /// for example `"; evaluator: httpStatus(429)"`. Never a response body.
    public var description: String
    /// The time of this request.
    public var elapsed: Duration
    /// `nil` when the evaluator did not report usage or the request failed.
    public var inputTokens: Int?
    /// The answers, in question order. Empty when the request failed.
    public var answers: [DecisionAnswer]
    /// Names of questions the evaluator refused, or answered with a value that was not
    /// offered or a number out of range. Each one used its fallback.
    public var refused: [String]
    /// Names of questions that used the catalog-order fallback (refused or below a
    /// threshold). A host can show "arranged in default order" when this is not empty.
    public var fallbacks: [String]
    /// The validator warnings of the spec this step published.
    public var validationWarnings: Int

    public init(
        index: Int, phase: Phase, description: String, elapsed: Duration, inputTokens: Int?,
        answers: [DecisionAnswer], refused: [String] = [], fallbacks: [String] = [],
        validationWarnings: Int = 0
    ) {
        self.index = index
        self.phase = phase
        self.description = description
        self.elapsed = elapsed
        self.inputTokens = inputTokens
        self.answers = answers
        self.refused = refused
        self.fallbacks = fallbacks
        self.validationWarnings = validationWarnings
    }
}

/// Why a composition ended.
public enum ComposeStopReason: String, Sendable, Hashable {
    /// The layout round finished, or no layout was needed.
    case finish
    /// A budget stopped the composition; the spec is the last valid preview.
    case limit
    /// The request cannot be fulfilled, or the evaluator failed.
    case unavailable
}

/// One event of `Composer.compose`. A `.step` is emitted only after its spec is validated;
/// a half tree is never published.
public enum ComposeEvent: Sendable, Hashable {
    case step(spec: Spec, step: ComposeStep)
    case complete(
        spec: Spec?, steps: [ComposeStep], elapsed: Duration, inputTokens: Int?,
        stopReason: ComposeStopReason)
}

/// Why a composer could not be created, or a composition could not start.
///
/// Named `CompositionError` because `JSONRenderCore` already has `ComposeError` for
/// `Spec.composing`.
public enum CompositionError: Error, Sendable, Hashable {
    /// A candidate the composer must refuse: unknown type, prop not in the schema, unknown
    /// event or action, an unsupported expression (`$computed`, `$template`, a directive),
    /// `repeat` or `watch`, a duplicate or reserved id, or `maxUses` below one.
    case invalidCandidate(id: String, reason: String)
    /// No candidate may be the root.
    case noRootCandidate
    /// A limit is not a positive number.
    case invalidLimits(String)
    /// A request could not be made (for example `.tooManyQuestions`).
    case evaluator(DecisionError)
    /// The evaluator returned the wrong number of answers or the wrong names. The composer
    /// records this code in the step; it never publishes a tree built from such answers.
    case invalidAnswer(question: String, reason: String)
}
