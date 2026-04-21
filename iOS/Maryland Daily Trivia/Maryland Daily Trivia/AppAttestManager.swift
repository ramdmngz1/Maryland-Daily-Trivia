//
//  AppAttestManager.swift
//  Maryland Daily Trivia
//
//  Manages Apple App Attest attestation + JWT token lifecycle.
//

import Foundation
import CryptoKit
#if !targetEnvironment(simulator)
import DeviceCheck
#endif

@MainActor
final class AppAttestManager {
    static let shared = AppAttestManager()

    private let baseURL = "https://maryland-trivia-contest.f22682jcz6.workers.dev"
    private static let decoder = JSONDecoder()

    // Keychain keys
    private let accessTokenKey  = "auth_access_token"
    private let refreshTokenKey = "auth_refresh_token"
    private let tokenExpiryKey  = "auth_token_expiry"
    private let attestKeyIdKey  = "auth_attest_key_id"

    private var isAuthenticating = false
    private var hasMigratedKeychain = false

    private init() {}

    // MARK: - Public API

    /// Main entry point — ensures a valid access token is available.
    func ensureAuthenticated() async throws {
        // Migrate sensitive Keychain items to ThisDeviceOnly accessibility (once per launch)
        if !hasMigratedKeychain {
            KeychainHelper.migrateToThisDeviceOnly(keys: [accessTokenKey, refreshTokenKey, tokenExpiryKey, attestKeyIdKey, "contest_user_id"])
            hasMigratedKeychain = true
        }

        // Already have a valid (non-expired) access token?
        if let expiry = tokenExpiry(), expiry > Date().addingTimeInterval(60),
           KeychainHelper.read(key: accessTokenKey) != nil {
            return
        }

        // Try refreshing
        if KeychainHelper.read(key: refreshTokenKey) != nil {
            do {
                try await refreshAccessToken()
                return
            } catch {
                // Refresh failed — fall through to full attestation
            }
        }

        // Full attestation
        try await performAttestation()
    }

    /// Returns the current access token (nil if not yet authenticated).
    func getAccessToken() -> String? {
        KeychainHelper.read(key: accessTokenKey)
    }

    /// Clears tokens and re-runs attestation (call on 401).
    func forceReauthenticate() async throws {
        clearTokens()
        try await performAttestation()
    }

    // MARK: - Attestation

    private func performAttestation() async throws {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        #if targetEnvironment(simulator)
            #if DEBUG
            try await performDebugAttestation()
            #else
            throw AttestError.unsupported
            #endif
        #else
        try await performRealAttestation()
        #endif
    }

    #if !targetEnvironment(simulator)
    private func performRealAttestation() async throws {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            throw AttestError.unsupported
        }

        let deviceId = KeychainHelper.getOrCreateUserId()

        // Apple only allows attestKey() to be called once per key — a key cannot be
        // re-attested. Any cached key from a previous failed or successful attestation
        // must be discarded so we generate a fresh one. (We don't use assertKey() in
        // this app, so there is no reason to hold on to a key across sessions.)
        KeychainHelper.delete(key: attestKeyIdKey)
        let keyId = try await service.generateKey()

        // 2. Get challenge from server
        let challenge = try await fetchChallenge(deviceId: deviceId)

        // 3. Hash the challenge and attest with Apple
        let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await service.attestKey(keyId, clientDataHash: hash)

        // 4. Send attestation to our server
        let tokens = try await sendAttestation(
            deviceId: deviceId,
            keyId: keyId,
            attestation: attestation.base64EncodedString()
        )
        storeTokens(tokens)
    }
    #endif

    #if DEBUG
    private func performDebugAttestation() async throws {
        let deviceId = KeychainHelper.getOrCreateUserId()

        // DEBUG_SECRET must be set as an environment variable in the Xcode scheme.
        // Edit Scheme → Run → Environment Variables → add DEBUG_SECRET with the value
        // from your staging backend's ENABLE_DEBUG_AUTH secret. Never hardcode this value.
        guard let debugSecret = ProcessInfo.processInfo.environment["DEBUG_SECRET"],
              !debugSecret.isEmpty else {
            throw AttestError.unsupported
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/auth/attest")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "deviceId": deviceId,
            "debugSecret": debugSecret
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await SecureSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AttestError.serverRejected
        }

        let tokens = try Self.decoder.decode(TokenResponse.self, from: data)
        storeTokens(tokens)
    }
    #endif

    // MARK: - Refresh

    private func refreshAccessToken() async throws {
        guard let refreshToken = KeychainHelper.read(key: refreshTokenKey) else {
            throw AttestError.noRefreshToken
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/auth/refresh")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refreshToken": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await SecureSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AttestError.refreshFailed
        }

        let result = try Self.decoder.decode(RefreshResponse.self, from: data)
        KeychainHelper.save(key: accessTokenKey, value: result.accessToken)
        let expiry = Date().addingTimeInterval(TimeInterval(result.expiresIn))
        KeychainHelper.save(key: tokenExpiryKey, value: String(expiry.timeIntervalSince1970))

        #if DEBUG
        Swift.print("[AppAttest] Token refreshed")
        #endif
    }

    // MARK: - Network helpers

    private func fetchChallenge(deviceId: String) async throws -> String {
        var components = URLComponents(string: "\(baseURL)/auth/challenge")!
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]

        let (data, response) = try await SecureSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AttestError.challengeFailed
        }

        let json = try Self.decoder.decode(ChallengeResponse.self, from: data)
        return json.challenge
    }

    private func sendAttestation(deviceId: String, keyId: String, attestation: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/auth/attest")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "deviceId": deviceId,
            "keyId": keyId,
            "attestation": attestation
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await SecureSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AttestError.serverRejected
        }

        return try Self.decoder.decode(TokenResponse.self, from: data)
    }

    // MARK: - Token storage

    private func storeTokens(_ tokens: TokenResponse) {
        KeychainHelper.save(key: accessTokenKey, value: tokens.accessToken)
        KeychainHelper.save(key: refreshTokenKey, value: tokens.refreshToken)
        let expiry = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        KeychainHelper.save(key: tokenExpiryKey, value: String(expiry.timeIntervalSince1970))
    }

    private func tokenExpiry() -> Date? {
        guard let raw = KeychainHelper.read(key: tokenExpiryKey),
              let ts = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private func clearTokens() {
        KeychainHelper.delete(key: accessTokenKey)
        KeychainHelper.delete(key: refreshTokenKey)
        KeychainHelper.delete(key: tokenExpiryKey)
    }

    // MARK: - Models

    private struct ChallengeResponse: Decodable {
        let challenge: String
    }

    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
    }

    enum AttestError: LocalizedError {
        case unsupported, challengeFailed, serverRejected, noRefreshToken, refreshFailed

        var errorDescription: String? {
            switch self {
            case .unsupported:     return "App Attest not supported on this device"
            case .challengeFailed: return "Failed to get attestation challenge"
            case .serverRejected:  return "Server rejected attestation"
            case .noRefreshToken:  return "No refresh token available"
            case .refreshFailed:   return "Token refresh failed"
            }
        }
    }
}
