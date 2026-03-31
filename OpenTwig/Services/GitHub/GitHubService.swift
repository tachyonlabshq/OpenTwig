import Foundation

// MARK: - GitHub API Types

struct GitHubUser: Codable, Sendable, Identifiable {
    var id: Int
    var login: String
    var name: String?
    var email: String?
    var avatarUrl: String
    var bio: String?
    var publicRepos: Int

    enum CodingKeys: String, CodingKey {
        case id, login, name, email, bio
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
    }
}

struct GitHubRepo: Codable, Sendable, Identifiable {
    var id: Int
    var name: String
    var fullName: String
    var description: String?
    var htmlUrl: String
    var cloneUrl: String
    var sshUrl: String
    var isPrivate: Bool
    var defaultBranch: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case sshUrl = "ssh_url"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
    }
}

struct GitHubPR: Codable, Sendable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var body: String?
    var state: String
    var htmlUrl: String
    var head: GitHubPRRef
    var base: GitHubPRRef
    var user: GitHubPRUser
    var createdAt: String
    var updatedAt: String
    var merged: Bool?
    var mergeable: Bool?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, head, base, user, merged, mergeable
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubPRRef: Codable, Sendable {
    var ref: String
    var sha: String
    var label: String?
}

struct GitHubPRUser: Codable, Sendable {
    var login: String
    var id: Int
    var avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
    }
}

enum MergeMethod: String, Codable, Sendable {
    case merge
    case squash
    case rebase
}

// MARK: - Rate Limit Info

struct GitHubRateLimit: Sendable {
    var limit: Int
    var remaining: Int
    var resetDate: Date
}

// MARK: - Errors

enum GitHubError: LocalizedError, Sendable {
    case unauthorized
    case notFound(String)
    case rateLimited(resetDate: Date)
    case serverError(statusCode: Int, message: String)
    case networkError(String)
    case decodingError(String)
    case noToken
    case invalidResponse
    case repositoryNotSet

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "GitHub authentication failed. Check your token."
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .rateLimited(let resetDate):
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "GitHub rate limit exceeded. Resets at \(formatter.string(from: resetDate))"
        case .serverError(let code, let message):
            return "GitHub server error (\(code)): \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to parse GitHub response: \(message)"
        case .noToken:
            return "No GitHub token configured"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .repositoryNotSet:
            return "No repository is set. Call setRepository(owner:name:) first."
        }
    }
}

// MARK: - GitHubService Actor

actor GitHubService {

    private var token: String?
    private var owner: String?
    private var repoName: String?
    private var rateLimit: GitHubRateLimit?

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: String = "https://api.github.com") {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        ]
        self.session = URLSession(configuration: config)
        guard let parsed = URL(string: baseURL) else {
            // Fall back to the known-good default rather than crashing.
            self.baseURL = URL(string: "https://api.github.com")!
            return
        }
        self.baseURL = parsed
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Configuration

    func authenticate(token: String) async throws {
        self.token = token
        // Validate the token by fetching user info.
        _ = try await fetchUser()
    }

    func setRepository(owner: String, name: String) {
        // Trim whitespace to prevent accidental spaces from breaking URL construction.
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repoName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var currentRateLimit: GitHubRateLimit? { rateLimit }

    // MARK: - User

    func fetchUser() async throws -> GitHubUser {
        return try await request(path: "/user")
    }

    // MARK: - Repositories

    func listRepos() async throws -> [GitHubRepo] {
        return try await request(path: "/user/repos", query: [
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "per_page", value: "100"),
        ])
    }

    // MARK: - Pull Requests

    func createPR(
        title: String,
        body: String,
        head: String,
        base: String
    ) async throws -> GitHubPR {
        let repoPath = try repositoryPath()

        struct CreatePRBody: Encodable {
            var title: String
            var body: String
            var head: String
            var base: String
        }

        let payload = CreatePRBody(title: title, body: body, head: head, base: base)
        return try await request(
            path: "/repos/\(repoPath)/pulls",
            method: "POST",
            body: payload
        )
    }

    func listPRs(state: String = "open") async throws -> [GitHubPR] {
        let repoPath = try repositoryPath()
        return try await request(
            path: "/repos/\(repoPath)/pulls",
            query: [
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "per_page", value: "100"),
            ]
        )
    }

    func fetchPRDiff(number: Int) async throws -> String {
        let repoPath = try repositoryPath()
        var urlRequest = try buildRequest(
            path: "/repos/\(repoPath)/pulls/\(number)",
            method: "GET"
        )
        urlRequest.setValue("application/vnd.github.diff", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: urlRequest)
        try handleHTTPResponse(response)
        updateRateLimit(from: response)

        guard let diff = String(data: data, encoding: .utf8) else {
            throw GitHubError.invalidResponse
        }
        return diff
    }

    func addPRComment(number: Int, body: String) async throws {
        let repoPath = try repositoryPath()

        struct CommentBody: Encodable {
            var body: String
        }

        let _: GitHubComment = try await request(
            path: "/repos/\(repoPath)/issues/\(number)/comments",
            method: "POST",
            body: CommentBody(body: body)
        )
    }

    func mergePR(number: Int, method: MergeMethod = .merge) async throws {
        let repoPath = try repositoryPath()

        struct MergeBody: Encodable {
            var merge_method: String
        }

        let _: MergePRResponse = try await request(
            path: "/repos/\(repoPath)/pulls/\(number)/merge",
            method: "PUT",
            body: MergeBody(merge_method: method.rawValue)
        )
    }

    // MARK: - Private: HTTP Layer

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil
    ) async throws -> T {
        let urlRequest = try buildRequest(path: path, method: method, query: query)
        return try await execute(urlRequest)
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> T {
        var urlRequest = try buildRequest(path: path, method: method)
        urlRequest.httpBody = try encoder.encode(body)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(urlRequest)
    }

    private func buildRequest(
        path: String,
        method: String,
        query: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard let token else { throw GitHubError.noToken }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = query

        guard let url = components?.url else {
            throw GitHubError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Check rate limit before making the request.
        if let rl = rateLimit, rl.remaining == 0, rl.resetDate > Date() {
            throw GitHubError.rateLimited(resetDate: rl.resetDate)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubError.networkError(error.localizedDescription)
        }

        updateRateLimit(from: response)
        try handleHTTPResponse(response)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubError.decodingError(error.localizedDescription)
        }
    }

    private func handleHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw GitHubError.unauthorized
        case 404:
            throw GitHubError.notFound(http.url?.path ?? "unknown")
        case 403:
            if let rl = rateLimit, rl.remaining == 0 {
                throw GitHubError.rateLimited(resetDate: rl.resetDate)
            }
            throw GitHubError.unauthorized
        default:
            throw GitHubError.serverError(
                statusCode: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    private func updateRateLimit(from response: URLResponse) {
        guard let http = response as? HTTPURLResponse else { return }

        let headers = http.allHeaderFields
        guard let limitStr = headers["X-RateLimit-Limit"] as? String,
              let remainingStr = headers["X-RateLimit-Remaining"] as? String,
              let resetStr = headers["X-RateLimit-Reset"] as? String,
              let limit = Int(limitStr),
              let remaining = Int(remainingStr),
              let resetTimestamp = Double(resetStr)
        else { return }

        rateLimit = GitHubRateLimit(
            limit: limit,
            remaining: remaining,
            resetDate: Date(timeIntervalSince1970: resetTimestamp)
        )
    }

    private func repositoryPath() throws -> String {
        guard let owner, let repoName else {
            throw GitHubError.repositoryNotSet
        }

        // Validate owner and repo name to prevent URL path injection.
        // GitHub usernames/org names: alphanumeric + hyphens, repo names:
        // alphanumeric, hyphens, underscores, dots.
        let ownerPattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$"#
        let repoPattern = #"^[a-zA-Z0-9._\-]+$"#

        guard owner.range(of: ownerPattern, options: .regularExpression) != nil,
              !owner.contains(".."),
              repoName.range(of: repoPattern, options: .regularExpression) != nil,
              !repoName.contains("..")
        else {
            throw GitHubError.notFound("Invalid repository identifier: \(owner)/\(repoName)")
        }

        return "\(owner)/\(repoName)"
    }
}

// MARK: - Private Response Types

private struct GitHubComment: Decodable {
    var id: Int
}

private struct MergePRResponse: Decodable {
    var sha: String?
    var merged: Bool?
    var message: String?
}
