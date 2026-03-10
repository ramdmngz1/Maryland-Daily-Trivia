import Foundation

// Ephemeral, host-allowlisted URLSession for sensitive calls
final class SecureSession {
    static let shared = SecureSession()

    // Only allow requests to these hosts over HTTPS
    private let allowedHosts: Set<String> = [
        "maryland-trivia-contest.f22682jcz6.workers.dev"
    ]

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func validate(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https" else { throw URLError(.badURL) }
        guard let host = url.host, allowedHosts.contains(host) else { throw URLError(.unsupportedURL) }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let url = request.url { try validate(url) }
        return try await session.data(for: request)
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try validate(url)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await session.data(for: req)
    }
}
