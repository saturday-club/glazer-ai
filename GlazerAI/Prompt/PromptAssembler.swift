// PromptAssembler.swift
// GlazerAI
//
// Assembles a research prompt by inserting OCR text into a template.

import Foundation

/// Assembles the research prompt sent to the Claude CLI.
struct PromptAssembler: Sendable {

    /// Placeholder token replaced with OCR text.
    static let placeholder = "{ocr_text}"

    /// Default research prompt template.
    static let defaultTemplate: String = {
        let intro = "The following text was extracted from a screenshot."
        let instruction = "Please research this topic thoroughly and provide a concise,"
        let detail = "well-structured summary with key facts and relevant context:"
        return "\(intro) \(instruction) \(detail)\n\n{ocr_text}"
    }()

    /// The template used for assembly.
    let template: String

    /// Creates an assembler with the given template.
    /// - Parameter template: Prompt template containing `{ocr_text}`. Defaults to ``defaultTemplate``.
    init(template: String = Self.defaultTemplate) {
        self.template = template
    }

    /// Replaces the `{ocr_text}` placeholder with the recognised text.
    ///
    /// - Parameter ocrText: The text extracted by OCR.
    /// - Returns: The fully assembled prompt string.
    func assemble(ocrText: String) -> String {
        template.replacingOccurrences(of: Self.placeholder, with: ocrText)
    }
}
