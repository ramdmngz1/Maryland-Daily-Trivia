import Foundation

enum APIEnvironment {
    static let host = "maryland-trivia-contest.f22682jcz6.workers.dev"
    static let baseURL = URL(string: "https://\(host)/")!
    static let allowedHosts: Set<String> = [host]

    static func url(path: String) -> URL {
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }
}

