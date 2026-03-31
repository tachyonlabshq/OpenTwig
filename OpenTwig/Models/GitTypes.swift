import Foundation

struct GitBranch: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var isRemote: Bool
    var isCurrent: Bool
    var lastCommit: GitCommit?
}

struct GitCommit: Identifiable, Codable, Hashable, Sendable {
    var id: String { sha }
    var sha: String
    var message: String
    var author: String
    var date: Date
    var parentSHAs: [String]

    var shortSHA: String { String(sha.prefix(7)) }

    var subject: String {
        message.components(separatedBy: .newlines).first ?? message
    }
}

struct GitDiff: Codable, Sendable {
    var hunks: [DiffHunk]
    var stats: DiffStats
}

struct DiffStats: Codable, Sendable {
    var additions: Int
    var deletions: Int
    var filesChanged: Int
}

struct DiffHunk: Codable, Sendable {
    var oldStart: Int
    var oldCount: Int
    var newStart: Int
    var newCount: Int
    var lines: [DiffLine]
}

enum DiffLineType: String, Codable, Sendable {
    case context
    case addition
    case deletion
}

struct DiffLine: Codable, Sendable {
    var type: DiffLineType
    var content: String
}

struct MergeConflict: Identifiable, Codable, Sendable {
    var id: String { path }
    var path: String
    var baseContent: String
    var oursContent: String
    var theirsContent: String
}

struct GitFileStatus: Codable, Hashable, Sendable {
    var path: String
    var status: FileStatusKind

    enum FileStatusKind: String, Codable, Sendable {
        case added
        case modified
        case deleted
        case renamed
        case untracked
    }
}

struct GitStatus: Codable, Sendable {
    var staged: [GitFileStatus]
    var modified: [GitFileStatus]
    var untracked: [GitFileStatus]

    var isEmpty: Bool {
        staged.isEmpty && modified.isEmpty && untracked.isEmpty
    }

    var totalChanges: Int {
        staged.count + modified.count + untracked.count
    }

    static let clean = GitStatus(staged: [], modified: [], untracked: [])
}
