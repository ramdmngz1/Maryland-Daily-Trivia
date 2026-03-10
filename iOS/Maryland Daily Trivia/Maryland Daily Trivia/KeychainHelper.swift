//
//  KeychainHelper.swift
//  Maryland Daily Trivia
//

import Foundation
import Security

enum KeychainHelper {

    /// Save a string value to the Keychain
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.marylanddailytrivia",
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Read a string value from the Keychain
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.marylanddailytrivia",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a value from the Keychain
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.marylanddailytrivia",
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Get or create the device user ID, migrating from UserDefaults if needed
    static func getOrCreateUserId() -> String {
        let key = "contest_user_id"

        // Check Keychain first
        if let existing = read(key: key) {
            return existing
        }

        // Migrate from UserDefaults if present
        if let legacy = UserDefaults.standard.string(forKey: key) {
            save(key: key, value: legacy)
            UserDefaults.standard.removeObject(forKey: key)
            return legacy
        }

        // Generate new ID
        let newId = "device_\(UUID().uuidString)"
        save(key: key, value: newId)
        return newId
    }

    /// Get username from Keychain, migrating from UserDefaults if needed
    static func getOrCreateUsername() -> String {
        let key = "contest_username"

        // Check Keychain first
        if let existing = read(key: key), !existing.isEmpty {
            return existing
        }

        // Migrate from UserDefaults if present
        if let legacy = UserDefaults.standard.string(forKey: key), !legacy.isEmpty {
            save(key: key, value: legacy)
            UserDefaults.standard.removeObject(forKey: key)
            return legacy
        }

        return ""
    }

    /// Save username to Keychain
    static func saveUsername(_ username: String) {
        save(key: "contest_username", value: username)
        // Clean up UserDefaults if it still exists
        UserDefaults.standard.removeObject(forKey: "contest_username")
    }

    /// Migrate a list of keys to ThisDeviceOnly accessibility
    static func migrateToThisDeviceOnly(keys: [String]) {
        for key in keys {
            if let value = read(key: key) {
                // Re-save with stronger accessibility
                save(key: key, value: value)
            }
        }
    }
}
