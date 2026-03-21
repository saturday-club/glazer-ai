// PromptAssemblerTests.swift
// GlazerAITests

import XCTest
@testable import GlazerAI

final class PromptAssemblerTests: XCTestCase {

    func test_assemble_replacesPlaceholder() {
        let assembler = PromptAssembler()
        let result = assembler.assemble(ocrText: "Swift concurrency")

        XCTAssertTrue(result.contains("Swift concurrency"))
        XCTAssertFalse(result.contains("{ocr_text}"))
    }

    func test_assemble_emptyOCRText_replacesPlaceholderWithEmpty() {
        let assembler = PromptAssembler()
        let result = assembler.assemble(ocrText: "")

        XCTAssertFalse(result.contains("{ocr_text}"))
        XCTAssertTrue(result.contains("research this topic"))
    }

    func test_assemble_multilineOCRText_preservesNewlines() {
        let assembler = PromptAssembler()
        let multiline = "Line 1\nLine 2\nLine 3"
        let result = assembler.assemble(ocrText: multiline)

        XCTAssertTrue(result.contains("Line 1\nLine 2\nLine 3"))
    }

    func test_assemble_customTemplate_usesProvidedTemplate() {
        let custom = "Summarise: {ocr_text}"
        let assembler = PromptAssembler(template: custom)
        let result = assembler.assemble(ocrText: "Hello")

        XCTAssertEqual(result, "Summarise: Hello")
    }

    func test_defaultTemplate_containsPlaceholder() {
        XCTAssertTrue(PromptAssembler.defaultTemplate.contains("{ocr_text}"))
    }
}
