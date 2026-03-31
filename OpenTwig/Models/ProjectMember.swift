import Foundation

enum ProjectRole: String, Codable, Comparable, Sendable, CaseIterable {
    case owner
    case maintainer
    case contributor
    case viewer

    private var rank: Int {
        switch self {
        case .owner: 0
        case .maintainer: 1
        case .contributor: 2
        case .viewer: 3
        }
    }

    static func < (lhs: ProjectRole, rhs: ProjectRole) -> Bool {
        lhs.rank < rhs.rank
    }

    var permissions: [String] {
        switch self {
        case .owner:
            return ["Read", "Write", "Create Branches", "Merge Branches",
                    "Review", "Manage Members", "Edit Settings", "Delete Project"]
        case .maintainer:
            return ["Read", "Write", "Create Branches", "Merge Branches",
                    "Review", "Edit Settings"]
        case .contributor:
            return ["Read", "Write", "Create Branches"]
        case .viewer:
            return ["Read"]
        }
    }
}

struct ProjectMember: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: String
    var username: String
    var displayName: String
    var role: ProjectRole
    var avatarURL: String?
    var joinedAt: Date

    var canWrite: Bool { role <= .contributor }
    var canMergeBranches: Bool { role <= .maintainer }
    var canManageMembers: Bool { role == .owner }
    var canDeleteProject: Bool { role == .owner }
    var canEditSettings: Bool { role <= .maintainer }
    var canCreateBranches: Bool { role <= .contributor }
    var canReview: Bool { role <= .maintainer }

    init(
        id: UUID = UUID(),
        userId: String,
        username: String,
        displayName: String,
        role: ProjectRole,
        avatarURL: String? = nil,
        joinedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.role = role
        self.avatarURL = avatarURL
        self.joinedAt = joinedAt
    }
}
