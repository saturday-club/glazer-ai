// PromptAssemblerTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class PromptAssemblerTests: XCTestCase {

    private let emptyProfile = CandidateProfile.empty

    func test_assemble_replacesOCRPlaceholder() {
        let assembler = PromptAssembler()
        let result = assembler.assemble(ocrText: "Swift concurrency", candidateProfile: emptyProfile)

        XCTAssertTrue(result.contains("Swift concurrency"))
        XCTAssertFalse(result.contains("{ocr_text}"))
    }

    func test_assemble_replacesCandidatePlaceholder() {
        let assembler = PromptAssembler()
        let result = assembler.assemble(ocrText: "some text", candidateProfile: emptyProfile)

        XCTAssertFalse(result.contains("{candidate_profile}"))
    }

    func test_assemble_emptyOCRText_replacesPlaceholderWithEmpty() {
        let assembler = PromptAssembler()
        let result = assembler.assemble(ocrText: "", candidateProfile: emptyProfile)

        XCTAssertFalse(result.contains("{ocr_text}"))
        XCTAssertTrue(result.contains("LinkedIn"))
    }

    func test_assemble_multilineOCRText_preservesNewlines() {
        let assembler = PromptAssembler()
        let multiline = "Line 1\nLine 2\nLine 3"
        let result = assembler.assemble(ocrText: multiline, candidateProfile: emptyProfile)

        XCTAssertTrue(result.contains("Line 1\nLine 2\nLine 3"))
    }

    func test_assemble_customTemplate_usesProvidedTemplate() {
        let custom = "Summarise: {ocr_text}"
        let assembler = PromptAssembler(template: custom)
        let result = assembler.assemble(ocrText: "Hello", candidateProfile: emptyProfile)

        XCTAssertEqual(result, "Summarise: Hello")
    }

    func test_assemble_withConfiguredProfile_includesName() {
        let profile = CandidateProfile(name: "Jane Doe", resumeText: "Software engineer at Acme")
        let assembler = PromptAssembler()
        let result = assembler.assemble(ocrText: "ocr", candidateProfile: profile)

        XCTAssertTrue(result.contains("Jane Doe"))
    }

    func test_defaultTemplate_containsOCRPlaceholder() {
        XCTAssertTrue(PromptAssembler.defaultTemplate.contains("{ocr_text}"))
    }

    func test_defaultTemplate_containsCandidatePlaceholder() {
        XCTAssertTrue(PromptAssembler.defaultTemplate.contains("{candidate_profile}"))
    }
}
