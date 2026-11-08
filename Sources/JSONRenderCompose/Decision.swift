/// The text the evaluator reads: the shared state, rendered once as JSON with sorted keys.
///
/// The composer puts only the user request, the host context, guidance and candidate
/// descriptions here. Element props, bindings and initial state are never in it.
public struct DecisionInput: Sendable, Hashable, Codable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

/// One offered value of a `choice` question (Decisions wire `{ value, description }`).
public struct DecisionChoice: Sendable, Hashable, Codable {
    public var value: String
    public var description: String

    public init(value: String, description: String) {
        self.value = value
        self.description = description
    }
}

/// One level of a `score` question (Decisions wire `{ label, description }`).
public struct DecisionLevel: Sendable, Hashable, Codable {
    public var label: String
    public var description: String

    public init(label: String, description: String) {
        self.label = label
        self.description = description
    }
}

/// One Decisions API question. `Codable` writes the Decisions wire shape:
/// `{ type, name, instructions, choices | levels }`.
public enum DecisionQuestion: Sendable, Hashable {
    /// A yes/no question; the answer is a probability.
    case predicate(name: String, instructions: String)
    /// One of the offered values.
    case choice(name: String, instructions: String, choices: [DecisionChoice])
    /// An ordinal level; the API accepts 2 to 10 levels.
    case score(name: String, instructions: String, levels: [DecisionLevel])

    public var name: String {
        switch self {
        case .predicate(let name, _), .choice(let name, _, _), .score(let name, _, _): name
        }
    }

    public var instructions: String {
        switch self {
        case .predicate(_, let text), .choice(_, let text, _), .score(_, let text, _): text
        }
    }

    /// The wire `type`.
    public var kind: String {
        switch self {
        case .predicate: "predicate"
        case .choice: "choice"
        case .score: "score"
        }
    }
}

/// One Decisions API answer. Answers come back in question order.
///
/// `Codable` reads and writes the Decisions wire shape: a choice's `probabilities` is an
/// array of `{ value, probability }`, a score's is an array of `{ value, label, probability }`,
/// and a refused question is `{ type: "refusal", name }`.
public enum DecisionAnswer: Sendable, Hashable {
    case predicate(name: String, probability: Double)
    case choice(
        name: String, choice: String, probabilities: [String: Double], confidence: Double)
    /// `score` is the probability-weighted level index (0-based).
    case score(name: String, score: Double, probabilities: [Int: Double], confidence: Double)
    case refusal(name: String)

    public var name: String {
        switch self {
        case .predicate(let name, _), .choice(let name, _, _, _), .score(let name, _, _, _),
            .refusal(let name):
            name
        }
    }
}

/// Token use for one request. The Decisions API charges input tokens only.
public struct DecisionUsage: Sendable, Hashable, Codable {
    public var inputTokens: Int

    public init(inputTokens: Int) {
        self.inputTokens = inputTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
    }
}

/// The answers to one request, in question order, and the token use.
public struct DecisionResponse: Sendable, Hashable, Codable {
    public var answers: [DecisionAnswer]
    public var usage: DecisionUsage?

    public init(answers: [DecisionAnswer], usage: DecisionUsage? = nil) {
        self.answers = answers
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey {
        case answers, usage
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answers = try container.decode([DecisionAnswer].self, forKey: .answers)
        usage = try container.decodeIfPresent(DecisionUsage.self, forKey: .usage)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(answers, forKey: .answers)
        try container.encodeIfPresent(usage, forKey: .usage)
    }
}

// MARK: - Wire Codable

private enum WireKeys: String, CodingKey {
    case type, name, instructions, choices, levels
    case probability, choice, probabilities, confidence, score
}

extension DecisionQuestion: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: WireKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let name = try container.decode(String.self, forKey: .name)
        let instructions = try container.decode(String.self, forKey: .instructions)
        switch type {
        case "predicate":
            self = .predicate(name: name, instructions: instructions)
        case "choice":
            self = .choice(
                name: name, instructions: instructions,
                choices: try container.decode([DecisionChoice].self, forKey: .choices))
        case "score":
            self = .score(
                name: name, instructions: instructions,
                levels: try container.decode([DecisionLevel].self, forKey: .levels))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown question type.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: WireKeys.self)
        try container.encode(kind, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(instructions, forKey: .instructions)
        switch self {
        case .predicate: break
        case .choice(_, _, let choices): try container.encode(choices, forKey: .choices)
        case .score(_, _, let levels): try container.encode(levels, forKey: .levels)
        }
    }
}

private struct WireChoiceProbability: Codable {
    var value: String
    var probability: Double
}

private struct WireScoreProbability: Codable {
    var value: Int
    var label: String?
    var probability: Double
}

extension DecisionAnswer: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: WireKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let name = try container.decode(String.self, forKey: .name)
        switch type {
        case "predicate":
            self = .predicate(
                name: name, probability: try container.decode(Double.self, forKey: .probability))
        case "choice":
            let rows =
                try container.decodeIfPresent([WireChoiceProbability].self, forKey: .probabilities)
                ?? []
            self = .choice(
                name: name, choice: try container.decode(String.self, forKey: .choice),
                probabilities: Dictionary(
                    rows.map { ($0.value, $0.probability) }, uniquingKeysWith: { first, _ in first }
                ),
                confidence: try container.decode(Double.self, forKey: .confidence))
        case "score":
            let rows =
                try container.decodeIfPresent([WireScoreProbability].self, forKey: .probabilities)
                ?? []
            self = .score(
                name: name, score: try container.decode(Double.self, forKey: .score),
                probabilities: Dictionary(
                    rows.map { ($0.value, $0.probability) }, uniquingKeysWith: { first, _ in first }
                ),
                confidence: try container.decode(Double.self, forKey: .confidence))
        case "refusal":
            self = .refusal(name: name)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown answer type.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: WireKeys.self)
        try container.encode(name, forKey: .name)
        switch self {
        case .predicate(_, let probability):
            try container.encode("predicate", forKey: .type)
            try container.encode(probability, forKey: .probability)
        case .choice(_, let choice, let probabilities, let confidence):
            try container.encode("choice", forKey: .type)
            try container.encode(choice, forKey: .choice)
            try container.encode(
                probabilities.keys.sorted().map {
                    WireChoiceProbability(value: $0, probability: probabilities[$0] ?? 0)
                }, forKey: .probabilities)
            try container.encode(confidence, forKey: .confidence)
        case .score(_, let score, let probabilities, let confidence):
            try container.encode("score", forKey: .type)
            try container.encode(score, forKey: .score)
            try container.encode(
                probabilities.keys.sorted().map {
                    WireScoreProbability(
                        value: $0, label: nil, probability: probabilities[$0] ?? 0)
                }, forKey: .probabilities)
            try container.encode(confidence, forKey: .confidence)
        case .refusal:
            try container.encode("refusal", forKey: .type)
        }
    }
}
