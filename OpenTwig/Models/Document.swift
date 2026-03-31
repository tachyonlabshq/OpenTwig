import Foundation
import Observation

@Observable
final class Document: Identifiable, Codable, @unchecked Sendable {
    let id: UUID
    var filename: String
    var relativePath: String
    var content: String
    var lastModified: Date
    var isModified: Bool
    var citations: [CitationReference]

    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    init(
        id: UUID = UUID(),
        filename: String,
        relativePath: String,
        content: String = "",
        lastModified: Date = .now,
        isModified: Bool = false,
        citations: [CitationReference] = []
    ) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.content = content
        self.lastModified = lastModified
        self.isModified = isModified
        self.citations = citations
    }

    enum CodingKeys: String, CodingKey {
        case id, filename, relativePath, content, lastModified, isModified, citations
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        content = try container.decode(String.self, forKey: .content)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        isModified = try container.decode(Bool.self, forKey: .isModified)
        citations = try container.decode([CitationReference].self, forKey: .citations)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(filename, forKey: .filename)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(content, forKey: .content)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(isModified, forKey: .isModified)
        try container.encode(citations, forKey: .citations)
    }
}
