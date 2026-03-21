// UserDefaultsShortcutTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class UserDefaultsShortcutTests: XCTestCase {

    private let suiteName = "com.glazerai.tests.shortcut"
    private var defaults: UserDefaults?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Round-trip

    func test_encode_decode_defaultShortcut_isEqual() throws {
        let original = KeyboardShortcut.defaultShortcut
        let data = try JSONEncoder().encode(original)
        defaults?.set(data, forKey: Constants.shortcutDefaultsKey)

        guard let stored = defaults?.data(forKey: Constants.shortcutDefaultsKey) else {
            XCTFail("Expected stored data")
            return
        }

        let decoded = try JSONDecoder().decode(KeyboardShortcut.self, from: stored)
        XCTAssertEqual(original, decoded)
    }

    func test_encode_decode_customShortcut_isEqual() throws {
        let custom = KeyboardShortcut(keyCode: 8, modifierFlags: 0x100108) // ⌘⇧C
        let data = try JSONEncoder().encode(custom)
        defaults?.set(data, forKey: Constants.shortcutDefaultsKey)

        guard let stored = defaults?.data(forKey: Constants.shortcutDefaultsKey) else {
            XCTFail("Expected stored data")
            return
        }
        let decoded = try JSONDecoder().decode(KeyboardShortcut.self, from: stored)
        XCTAssertEqual(custom, decoded)
    }

    func test_missingKey_returnsNil() {
        XCTAssertNil(defaults?.data(forKey: Constants.shortcutDefaultsKey))
    }
}
