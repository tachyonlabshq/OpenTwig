import Foundation

// MARK: - Merge Context & Suggestion Types

struct MergeContext: Sendable {
    /// Lines of surrounding text (approximately +-100 lines around each conflict).
    var surroundingText: String
    /// Commit messages from both branches involved in the merge.
    var commitMessages: [String]
    /// PR comments providing reviewer intent.
    var prComments: [String]
    /// Bibliography entries relevant to the conflicting region.
    var bibliography: [String]
}

struct AIMergeSuggestion: Codable, Sendable {
    var resolvedContent: String
    var confidence: Double
    var reasoning: String
    var changesDescription: String
    var requiresHumanReview: Bool

    /// True if confidence falls below the human review threshold.
    var isLowConfidence: Bool { confidence < 0.7 }
}

// MARK: - Errors

enum AIMergeError: LocalizedError, Sendable {
    case noAPIKey
    case requestFailed(String)
    case invalidResponse(String)
    case residualConflictMarkers(path: String)
    case fabricatedCitation(path: String, citekey: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "AI API key not configured. Set it in Settings."
        case .requestFailed(let msg):
            return "AI merge request failed: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid AI response: \(msg)"
        case .residualConflictMarkers(let path):
            return "AI resolution for '\(path)' still contains conflict markers"
        case .fabricatedCitation(let path, let citekey):
            return "AI resolution for '\(path)' contains a citekey '\(citekey)' not present in the source material"
        case .decodingFailed(let msg):
            return "Failed to decode AI response: \(msg)"
        }
    }
}

// MARK: - AIMergeService Actor

actor AIMergeService {

    private let configuration: AIConfiguration
    private let session: URLSession

    init(configuration: AIConfiguration = .load()) {
        self.configuration = configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Resolve a single merge conflict using AI.
    func resolveConflict(
        _ conflict: MergeConflict,
        context: MergeContext
    ) async throws -> AIMergeSuggestion {
        let prompt = buildPrompt(conflict: conflict, context: context)
        let response = try await callClaude(prompt: prompt)
        let suggestion = try parseResponse(response)

        // Validation: no residual conflict markers.
        try validateNoConflictMarkers(suggestion.resolvedContent, path: conflict.path)

        // Validation: no fabricated citations.
        try validateNoCitationFabrication(
            resolved: suggestion.resolvedContent,
            ours: conflict.oursContent,
            theirs: conflict.theirsContent,
            base: conflict.baseContent,
            path: conflict.path
        )

        return suggestion
    }

    /// Resolve all conflicts in a batch. Returns suggestions in the same order.
    func resolveAll(
        _ conflicts: [MergeConflict],
        context: MergeContext
    ) async throws -> [AIMergeSuggestion] {
        var suggestions: [AIMergeSuggestion] = []
        suggestions.reserveCapacity(conflicts.count)

        for conflict in conflicts {
            let suggestion = try await resolveConflict(conflict, context: context)
            suggestions.append(suggestion)
        }

        return suggestions
    }

    // MARK: - Private: Prompt Construction

    /// Build the system + user prompt following the 5 merge principles:
    /// 1. Preservation: never discard scholarly content
    /// 2. Fidelity: maintain exact citations, quotes, data
    /// 3. Combination: merge complementary additions from both sides
    /// 4. Transparency: explain every decision with reasoning
    /// 5. Academic tone: preserve formal academic register
    private func buildPrompt(conflict: MergeConflict, context: MergeContext) -> (system: String, user: String) {
        let system = """
        You are an expert academic document merge assistant. Your job is to resolve Git merge \
        conflicts in scholarly documents (LaTeX, Markdown with citations, etc.).

        Follow these 5 principles strictly:

        1. PRESERVATION: Never discard scholarly content from either side. If both sides add \
        meaningful text, combine them. Deletions must be justified.

        2. FIDELITY: Maintain exact citations, direct quotes, numerical data, and references. \
        Never alter a citekey, DOI, figure number, or quoted passage.

        3. COMBINATION: When both sides add complementary material (e.g., one adds a paragraph, \
        the other adds a citation), integrate both contributions logically.

        4. TRANSPARENCY: Explain every choice you make. State which parts came from which side \
        and why the combination is correct.

        5. ACADEMIC TONE: Preserve formal academic register. Do not introduce colloquial language \
        or alter the writing style.

        Respond ONLY with a JSON object matching this schema:
        {
          "resolvedContent": "<merged text>",
          "confidence": <0.0-1.0>,
          "reasoning": "<explanation of merge decisions>",
          "changesDescription": "<brief summary of what changed>"
        }

        If confidence is below 0.7, set reasoning to explain what is uncertain.
        Do NOT include conflict markers (<<<<<<, ======, >>>>>>) in resolvedContent.
        Do NOT invent citations or citekeys that do not appear in the input.
        """

        var userParts: [String] = []

        userParts.append("## Merge Conflict in: \(conflict.path)")
        userParts.append("")

        if !conflict.baseContent.isEmpty {
            userParts.append("### Base (common ancestor):")
            userParts.append("```")
            userParts.append(conflict.baseContent)
            userParts.append("```")
        }

        userParts.append("### Ours (current branch):")
        userParts.append("```")
        userParts.append(conflict.oursContent)
        userParts.append("```")

        userParts.append("### Theirs (incoming branch):")
        userParts.append("```")
        userParts.append(conflict.theirsContent)
        userParts.append("```")

        if !context.surroundingText.isEmpty {
            userParts.append("### Surrounding context (+-100 lines):")
            userParts.append("```")
            userParts.append(context.surroundingText)
            userParts.append("```")
        }

        if !context.commitMessages.isEmpty {
            userParts.append("### Relevant commit messages:")
            for msg in context.commitMessages {
                userParts.append("- \(msg)")
            }
        }

        if !context.prComments.isEmpty {
            userParts.append("### PR review comments:")
            for comment in context.prComments {
                userParts.append("- \(comment)")
            }
        }

        if !context.bibliography.isEmpty {
            userParts.append("### Bibliography entries referenced:")
            for entry in context.bibliography {
                userParts.append(entry)
            }
        }

        userParts.append("")
        userParts.append("Resolve this conflict following the 5 principles. Return JSON only.")

        return (system: system, user: userParts.joined(separator: "\n"))
    }

    // MARK: - Private: Claude API Call

    private func callClaude(prompt: (system: String, user: String)) async throws -> Data {
        guard let apiKey = configuration.apiKey else {
            throw AIMergeError.noAPIKey
        }

        guard let url = URL(string: "\(configuration.baseURL)/v1/messages") else {
            throw AIMergeError.requestFailed("Invalid base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": configuration.maxTokens,
            "temperature": configuration.temperature,
            "system": prompt.system,
            "messages": [
                ["role": "user", "content": prompt.user]
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIMergeError.requestFailed("Invalid response type")
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIMergeError.requestFailed("HTTP \(http.statusCode): \(bodyStr)")
        }

        return data
    }

    // MARK: - Private: Response Parsing

    private func parseResponse(_ data: Data) throws -> AIMergeSuggestion {
        // The Claude API returns a structured message; extract the text content.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String
        else {
            throw AIMergeError.invalidResponse("Could not extract text from API response")
        }

        // The text should be a JSON object matching AIMergeSuggestion.
        guard let jsonData = text.data(using: .utf8) else {
            throw AIMergeError.decodingFailed("Response text is not valid UTF-8")
        }

        // Try to extract JSON from text (may be wrapped in markdown code fences).
        let cleanedJSON = Self.extractJSON(from: text)
        guard let cleanData = cleanedJSON.data(using: .utf8) else {
            throw AIMergeError.decodingFailed("Cleaned JSON is not valid UTF-8")
        }

        struct RawSuggestion: Decodable {
            var resolvedContent: String
            var confidence: Double
            var reasoning: String
            var changesDescription: String
        }

        do {
            let raw = try JSONDecoder().decode(RawSuggestion.self, from: cleanData)
            return AIMergeSuggestion(
                resolvedContent: raw.resolvedContent,
                confidence: raw.confidence,
                reasoning: raw.reasoning,
                changesDescription: raw.changesDescription,
                requiresHumanReview: raw.confidence < 0.7
            )
        } catch {
            throw AIMergeError.decodingFailed(error.localizedDescription)
        }
    }

    /// Strip markdown code fences if the model wraps its JSON output in them.
    private static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private: Validation

    private func validateNoConflictMarkers(_ content: String, path: String) throws {
        let markers = ["<<<<<<<", "=======", ">>>>>>>"]
        for marker in markers {
            if content.contains(marker) {
                throw AIMergeError.residualConflictMarkers(path: path)
            }
        }
    }

    private func validateNoCitationFabrication(
        resolved: String,
        ours: String,
        theirs: String,
        base: String,
        path: String
    ) throws {
        // Extract @citekey patterns from the resolved content and verify each
        // exists in at least one of the source texts.
        let citekeyPattern = #"@([a-zA-Z][\w:.#$%&\-+?<>~/]*)"#
        guard let regex = try? NSRegularExpression(pattern: citekeyPattern) else { return }

        let sourceMaterial = "\(ours)\n\(theirs)\n\(base)"

        let nsResolved = resolved as NSString
        let matches = regex.matches(in: resolved, range: NSRange(location: 0, length: nsResolved.length))

        for match in matches {
            let citekey = nsResolved.substring(with: match.range(at: 1))
            if !sourceMaterial.contains("@\(citekey)") {
                throw AIMergeError.fabricatedCitation(path: path, citekey: citekey)
            }
        }
    }
}
