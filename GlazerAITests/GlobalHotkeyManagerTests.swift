// GlobalHotkeyManagerTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class GlobalHotkeyManagerTests: XCTestCase {

    // MARK: - Lifecycle

    func test_initialState_notRegistered() {
        let manager = GlobalHotkeyManager()
        XCTAssertFalse(manager.isRegistered)
    }

    func test_unregister_whenNotRegistered_doesNotCrash() {
        let manager = GlobalHotkeyManager()
        XCTAssertNoThrow(manager.unregister())
    }

    func test_unregister_afterRegister_setsIsRegisteredFalse() {
        let manager = GlobalHotkeyManager()
        // Note: register() may return false in unit test environment (no Accessibility
        // permission), but unregister() must still leave isRegistered == false.
        _ = manager.register(shortcut: .defaultShortcut) {}
        manager.unregister()
        XCTAssertFalse(manager.isRegistered)
    }

    func test_deinit_doesNotCrash() {
        var manager: GlobalHotkeyManager? = GlobalHotkeyManager()
        _ = manager?.register(shortcut: .defaultShortcut) {}
        manager = nil // triggers deinit → unregister
    }

    // MARK: - Shortcut Model

    func test_defaultShortcut_codableRoundtrip() throws {
        let shortcut = KeyboardShortcut.defaultShortcut
        let encoded  = try JSONEncoder().encode(shortcut)
        let decoded  = try JSONDecoder().decode(KeyboardShortcut.self, from: encoded)
        XCTAssertEqual(shortcut, decoded)
    }
}
