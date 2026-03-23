// ClaudeResponseTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class ClaudeResponseTests: XCTestCase {

    // MARK: - Success Parsing

    func test_parse_validSuccessJSON_decodesProfile() throws {
        let json = """
        {
          "status": "success",
          "profile": {
            "name": "Jane Doe",
            "headline": "iOS Engineer",
            "company": "Acme Corp",
            "location": "San Francisco, CA",
            "connections": "500+",
            "about": "Passionate about mobile.",
            "experience": ["Acme Corp — iOS Engineer"],
            "education": ["MIT — BS Computer Science"],
            "skills": ["Swift", "Xcode"]
          },
          "summary": "Jane is an iOS engineer at Acme Corp.",
          "message": null
        }
        """
        let response = try ClaudeResponse.parse(from: json)

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(response.profile?.name, "Jane Doe")
        XCTAssertEqual(response.profile?.headline, "iOS Engineer")
        XCTAssertEqual(response.profile?.company, "Acme Corp")
        XCTAssertEqual(response.profile?.skills, ["Swift", "Xcode"])
        XCTAssertEqual(response.summary, "Jane is an iOS engineer at Acme Corp.")
        XCTAssertNil(response.message)
    }

    // MARK: - No Profile Found Parsing

    func test_parse_noProfileFoundJSON_decodesStatus() throws {
        let json = """
        {
          "status": "no_profile_found",
          "profile": null,
          "summary": null,
          "message": "The captured text does not appear to contain a LinkedIn profile."
        }
        """
        let response = try ClaudeResponse.parse(from: json)

        XCTAssertEqual(response.status, .noProfileFound)
        XCTAssertNil(response.profile)
        XCTAssertNil(response.summary)
        XCTAssertNotNil(response.message)
    }

    // MARK: - Markdown Fence Stripping

    func test_parse_jsonWrappedInMarkdownFence_stripsAndDecodes() throws {
        let fenced = """
        ```json
        {"status":"no_profile_found","profile":null,"summary":null,"message":"No profile."}
        ```
        """
        let response = try ClaudeResponse.parse(from: fenced)
        XCTAssertEqual(response.status, .noProfileFound)
    }

    func test_parse_jsonWrappedInPlainFence_stripsAndDecodes() throws {
        let fenced = """
        ```
        {"status":"no_profile_found","profile":null,"summary":null,"message":"No profile."}
        ```
        """
        let response = try ClaudeResponse.parse(from: fenced)
        XCTAssertEqual(response.status, .noProfileFound)
    }

    // MARK: - Error Cases

    func test_parse_invalidJSON_throwsParseError() {
        let bad = "not json at all"
        XCTAssertThrowsError(try ClaudeResponse.parse(from: bad)) { error in
            XCTAssertTrue(error is ClaudeResponse.ParseError)
        }
    }

    func test_parse_emptyString_throwsParseError() {
        XCTAssertThrowsError(try ClaudeResponse.parse(from: "")) { error in
            XCTAssertTrue(error is ClaudeResponse.ParseError)
        }
    }

    // MARK: - Partial Profile

    func test_parse_partialProfile_nilFieldsAreNil() throws {
        let json = """
        {
          "status": "success",
          "profile": {"name": "John"},
          "summary": null,
          "message": null
        }
        """
        let response = try ClaudeResponse.parse(from: json)
        XCTAssertEqual(response.profile?.name, "John")
        XCTAssertNil(response.profile?.headline)
        XCTAssertNil(response.profile?.experience)
    }
}
