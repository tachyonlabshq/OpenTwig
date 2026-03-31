import Foundation

struct CSLName: Codable, Hashable, Sendable {
    var family: String
    var given: String?

    var displayName: String {
        if let given {
            return "\(family), \(given)"
        }
        return family
    }
}

struct CSLDate: Codable, Hashable, Sendable {
    // CSL date-parts: [[year, month, day]] or [[year, month]] or [[year]]
    var dateParts: [[Int]]

    var year: Int? { dateParts.first?.first }
    var month: Int? { dateParts.first?[safe: 1] }
    var day: Int? { dateParts.first?[safe: 2] }

    enum CodingKeys: String, CodingKey {
        case dateParts = "date-parts"
    }
}

private extension Array where Element == Int {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum CSLItemType: String, Codable, Sendable {
    case articleJournal = "article-journal"
    case book
    case chapter
    case conferencePaper = "paper-conference"
    case thesis
    case report
    case webpage
    case dataset
    case software
    case preprint
    case manuscript
    case article
    case review
}

struct CSLItem: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var type: CSLItemType
    var title: String
    var author: [CSLName]?
    var issued: CSLDate?
    var containerTitle: String?
    var volume: String?
    var issue: String?
    var page: String?
    var doi: String?
    var url: String?
    var abstract: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, author, issued, abstract
        case containerTitle = "container-title"
        case volume, issue, page
        case doi = "DOI"
        case url = "URL"
    }
}

struct CitationReference: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var citeKey: String
    var locationInDocument: Range<Int>?

    // Range is not Codable by default; encode as two integers.
    enum CodingKeys: String, CodingKey {
        case id, citeKey, locationStart, locationEnd
    }

    init(id: UUID = UUID(), citeKey: String, locationInDocument: Range<Int>? = nil) {
        self.id = id
        self.citeKey = citeKey
        self.locationInDocument = locationInDocument
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        citeKey = try container.decode(String.self, forKey: .citeKey)
        if let start = try container.decodeIfPresent(Int.self, forKey: .locationStart),
           let end = try container.decodeIfPresent(Int.self, forKey: .locationEnd) {
            locationInDocument = start..<end
        } else {
            locationInDocument = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(citeKey, forKey: .citeKey)
        try container.encodeIfPresent(locationInDocument?.lowerBound, forKey: .locationStart)
        try container.encodeIfPresent(locationInDocument?.upperBound, forKey: .locationEnd)
    }
}
