import Foundation
import Observation

enum ProjectStatus: String, Codable, Sendable {
    case cloning
    case ready
    case syncing
    case error
}

@Observable
final class Project: Identifiable, Codable, @unchecked Sendable {
    let id: UUID
    var name: String
    var localPath: URL?
    var remoteURL: String
    var currentBranch: String
    var description: String
    var createdAt: Date
    var lastOpenedAt: Date
    var members: [ProjectMember]
    var status: ProjectStatus

    init(
        id: UUID = UUID(),
        name: String,
        localPath: URL? = nil,
        remoteURL: String,
        currentBranch: String = "main",
        description: String = "",
        createdAt: Date = .now,
        lastOpenedAt: Date = .now,
        members: [ProjectMember] = [],
        status: ProjectStatus = .ready
    ) {
        self.id = id
        self.name = name
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.currentBranch = currentBranch
        self.description = description
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.members = members
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id, name, localPath, remoteURL, currentBranch, description
        case createdAt, lastOpenedAt, members, status
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        localPath = try container.decodeIfPresent(URL.self, forKey: .localPath)
        remoteURL = try container.decode(String.self, forKey: .remoteURL)
        currentBranch = try container.decode(String.self, forKey: .currentBranch)
        description = try container.decode(String.self, forKey: .description)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastOpenedAt = try container.decode(Date.self, forKey: .lastOpenedAt)
        members = try container.decode([ProjectMember].self, forKey: .members)
        status = try container.decode(ProjectStatus.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(localPath, forKey: .localPath)
        try container.encode(remoteURL, forKey: .remoteURL)
        try container.encode(currentBranch, forKey: .currentBranch)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastOpenedAt, forKey: .lastOpenedAt)
        try container.encode(members, forKey: .members)
        try container.encode(status, forKey: .status)
    }
}
