/// Budgets and thresholds for one composition. A host tunes the thresholds with labelled
/// examples; the defaults follow VPLAN 9.5.
public struct ComposeLimits: Sendable, Hashable {
    /// The element budget, including the root (upstream `maxElements`).
    public var maxElements: Int
    /// The deepest nesting; the root has depth one (upstream `maxDepth`).
    public var maxDepth: Int
    /// The request budget. Two rounds are used; below two, the composer stops after the
    /// preview with `.limit`.
    public var maxRounds: Int
    /// The question cap for one request. The Decisions API documents 400.
    public var maxQuestionsPerRequest: Int
    /// A predicate includes its candidate at a probability at or above this value.
    public var includeProbability: Double
    /// A choice or score is accepted at a confidence at or above this value; below it the
    /// composer uses the catalog-order fallback and records it in `ComposeStep.fallbacks`.
    public var choiceConfidence: Double
    /// The element caps for the density levels sparse, normal and dense. The density answer
    /// only lowers the budget; it never adds elements. Each cap is also capped by
    /// `maxElements`.
    public var densityBudget: [Int]

    public static let `default` = ComposeLimits()

    /// The Decisions API question cap per request (documented, not probed).
    public static let apiQuestionCap = 400

    public init(
        maxElements: Int = 32, maxDepth: Int = 8, maxRounds: Int = 3,
        maxQuestionsPerRequest: Int = ComposeLimits.apiQuestionCap,
        includeProbability: Double = 0.5, choiceConfidence: Double = 0.35,
        densityBudget: [Int] = [4, 12, 32]
    ) {
        self.maxElements = maxElements
        self.maxDepth = maxDepth
        self.maxRounds = maxRounds
        self.maxQuestionsPerRequest = maxQuestionsPerRequest
        self.includeProbability = includeProbability
        self.choiceConfidence = choiceConfidence
        self.densityBudget = densityBudget
    }
}

/// App guidance appended to the composer's instructions (upstream `instructions`).
public struct ComposeInstructions: Sendable, Hashable {
    /// Appended to the root question.
    public var root: String
    /// Shared guidance for the selection round (the input's `guidance` field).
    public var next: String
    /// Appended to each parent question in the layout round.
    public var parent: String

    public init(root: String = "", next: String = "", parent: String = "") {
        self.root = root
        self.next = next
        self.parent = parent
    }
}
