import Foundation

enum ActivityEventType: String, Codable, Sendable, CaseIterable {
    case commit
    case push
    case pull
    case branchCreated
    case branchMerged
    case prOpened
    case prMerged
    case citationAdded
    case citationRemoved
    case aiSuggestionCreated
    case aiSuggestionAccepted
    case aiSuggestionRejected
    case memberAdded
    case memberRemoved
    case documentCreated
    case documentDeleted
    case exportGenerated
}

struct ActivityEvent: Identifiable, Codable, Sendable {
    let id: UUID
    var projectId: UUID
    var userId: String
    var username: String
    var eventType: ActivityEventType
    var description: String
    var metadata: [String: String]
    var timestamp: Date

    init(
        id: UUID = UUID(),
        projectId: UUID,
        userId: String,
        username: String,
        eventType: ActivityEventType,
        description: String,
        metadata: [String: String] = [:],
        timestamp: Date = .now
    ) {
        self.id = id
        self.projectId = projectId
        self.userId = userId
        self.username = username
        self.eventType = eventType
        self.description = description
        self.metadata = metadata
        self.timestamp = timestamp
    }
}
