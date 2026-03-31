import Foundation

enum MergeStrategy: String, Codable, Sendable {
    case combine
    case preferOurs
    case preferTheirs
    case rewrite
    case needsHumanReview
}

enum SuggestionStatus: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
    case applied
}

struct AISuggestion: Identifiable, Codable, Sendable {
    let id: UUID
    var conflictPath: String
    var strategy: MergeStrategy
    var resolvedText: String
    var reasoning: String
    var confidence: Double
    var citationsAffected: Bool
    var warnings: [String]
    var status: SuggestionStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        conflictPath: String,
        strategy: MergeStrategy,
        resolvedText: String,
        reasoning: String,
        confidence: Double,
        citationsAffected: Bool = false,
        warnings: [String] = [],
        status: SuggestionStatus = .pending,
        createdAt: Date = .now
    ) {
        precondition((0...1).contains(confidence), "Confidence must be between 0 and 1")
        self.id = id
        self.conflictPath = conflictPath
        self.strategy = strategy
        self.resolvedText = resolvedText
        self.reasoning = reasoning
        self.confidence = confidence
        self.citationsAffected = citationsAffected
        self.warnings = warnings
        self.status = status
        self.createdAt = createdAt
    }

    var isHighConfidence: Bool { confidence >= 0.8 }
    var requiresReview: Bool { strategy == .needsHumanReview || !isHighConfidence || citationsAffected }
}
