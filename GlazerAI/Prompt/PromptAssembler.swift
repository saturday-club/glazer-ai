// PromptAssembler.swift
// GlazerAI
//
// Assembles the research + ice-breaker prompt sent to the Claude CLI.
// Uses OCR text of the target and the sender's own candidate profile.

import Foundation

/// Assembles the research prompt sent to the Claude CLI.
struct PromptAssembler: Sendable {

    /// Placeholder replaced with the target's OCR text.
    static let ocrPlaceholder = "{ocr_text}"
    /// Placeholder replaced with the sender's candidate profile summary.
    static let candidatePlaceholder = "{candidate_profile}"

    // swiftlint:disable line_length
    /// LinkedIn research + ice-breaker prompt template.
    static let defaultTemplate: String = """
    Extract the LinkedIn profile from the OCR text below. Then write a connection note.

    ## SENDER
    {candidate_profile}

    ## TASK
    1. Parse the OCR text for: name, headline, company, location, about, experience, education, skills.
    2. Write a connection note (max 300 chars) that sounds like a real person texting, not a LinkedIn bot.

    ## HOW THE NOTE MUST SOUND
    Write it like a warm DM to someone you think is cool and want to grab coffee with. Be genuine. Compliment something specific they did. Show you paid attention. Then ask a real question.

    The tone should feel like: "hey, what you're doing is sick, here's why I think so, can we talk about X?"

    FORMATTING:
    - No dashes (not -- or -) to join clauses. Use periods or commas instead.
    - No semicolons. Keep sentences simple.
    - 2 to 4 sentences max. Each one earns its place.

    BANNED (instant reject):
    - "Happy to connect" / "Love to connect" / "Excited to connect"
    - "I came across" / "I noticed" / "I was impressed by"
    - Any -ly adverb (genuinely, truly, really, deeply, highly)
    - "Innovative" / "impressive" / "passionate" / "synergies" / "landscape"
    - "At the intersection of" / "in the space of"
    - Starting with your own credentials ("MS Data Science here", "As a fellow...")
    - Ending with a generic ask ("Would love to chat", "Let's connect")
    - Using dashes to connect thoughts ("AI marketing + consumer behavior" is fine, but "I work on ML -- pattern recognition maps onto..." is not)

    REQUIRED:
    - Open with something specific about THEM that shows you looked at their profile
    - Include a genuine compliment about their work, role, or an achievement (glaze them a little, but make it specific and earned, not generic flattery)
    - Say briefly why it caught your attention from your perspective
    - End with a concrete question they'd want to answer

    GOOD:
    "The AMA exec VP role while doing consumer behavior research is a wild combo. Not many people run a marketing org and study the science behind it at the same time. I work on ML at IU and keep running into behavioral modeling questions. How are you using AI tools for AMA campaigns?"

    "Love that you're bridging brand strategy with AI marketing at Kelley. That crossover barely existed two years ago. I do ML research at IU and the consumer behavior side keeps pulling me in. What got you into the AI angle?"

    BAD:
    "Hi Manya, MS Data Science at IU here. I apply ML to brain imaging, but consumer behavior modeling uses the same toolkit. Happy to connect."

    "AMA VP + consumer behavior + AI is an unusual stack for Kelley. I work on ML for brain imaging at IU -- pattern recognition there maps onto behavioral modeling in ways I didn't expect. What AI tools are you running for AMA campaigns?"

    ## RETURN FORMAT
    Respond with ONLY valid JSON. No markdown fences.

    If no LinkedIn profile found:
    {"status":"no_profile_found","profile":null,"research":null,"iceBreakerNote":null,"summary":null,"message":"No LinkedIn profile detected."}

    If found:
    {"status":"success","profile":{"name":"...","headline":"...","company":"...","location":"...","connections":"...","about":"...","experience":["..."],"education":["..."],"skills":["..."]},"research":{"recentActivity":["..."],"publications":["..."],"companyContext":"...","conversationAngles":["..."]},"iceBreakerNote":"...","summary":"...","message":null}

    Null for unknown fields. Keep summary to 1-2 plain sentences.

    ## OCR TEXT
    {ocr_text}
    """
    // swiftlint:enable line_length

    static let jobDescriptionPlaceholder = "{job_description}"
    static let profileSummaryPlaceholder = "{profile_summary}"

    // swiftlint:disable line_length
    static let iceBreakerRefinementTemplate: String = """
    Rewrite the connection note to fit this job description. Same voice rules: short, specific, human. No corporate speak, no adverbs, no "happy to connect."

    ## SENDER
    {candidate_profile}

    ## TARGET
    {profile_summary}

    ## JOB
    {job_description}

    Max 300 chars. Reference something specific from their background that relates to the job. End with a concrete question or offer.

    Respond with ONLY valid JSON (no markdown fences):
    {"status":"success","iceBreakerNote":"...","message":null}
    """
    // swiftlint:enable line_length

    let template: String

    init(template: String = Self.defaultTemplate) {
        self.template = template
    }

    /// Assembles the prompt with both the target OCR text and the sender's profile.
    func assemble(ocrText: String, candidateProfile: CandidateProfile) -> String {
        let candidateSummary = buildCandidateSummary(candidateProfile)
        return template
            .replacingOccurrences(of: Self.ocrPlaceholder, with: ocrText)
            .replacingOccurrences(of: Self.candidatePlaceholder, with: candidateSummary)
    }

    /// Assembles a focused ice-breaker refinement prompt using existing profile data and a job description.
    func assembleRefinement(
        response: ClaudeResponse,
        jobDescription: String,
        candidateProfile: CandidateProfile
    ) -> String {
        let profileSummary = buildProfileSummary(response)
        let candidateSummary = buildCandidateSummary(candidateProfile)
        return Self.iceBreakerRefinementTemplate
            .replacingOccurrences(of: Self.candidatePlaceholder, with: candidateSummary)
            .replacingOccurrences(of: Self.profileSummaryPlaceholder, with: profileSummary)
            .replacingOccurrences(of: Self.jobDescriptionPlaceholder, with: jobDescription)
    }

    // MARK: - Private

    private func buildProfileSummary(_ response: ClaudeResponse) -> String {
        var parts: [String] = []
        if let name = response.profile?.name { parts.append("Name: \(name)") }
        if let headline = response.profile?.headline { parts.append("Headline: \(headline)") }
        if let company = response.profile?.company { parts.append("Company: \(company)") }
        if let summary = response.summary { parts.append("Summary: \(summary)") }
        if let note = response.iceBreakerNote { parts.append("Current note: \(note)") }
        return parts.joined(separator: "\n")
    }

    private func buildCandidateSummary(_ profile: CandidateProfile) -> String {
        guard profile.isConfigured else {
            return "(No sender profile configured — generate a generic but genuine ice-breaker)"
        }
        var parts: [String] = []
        if !profile.name.isEmpty { parts.append("Name: \(profile.name)") }
        if !profile.resumeText.isEmpty { parts.append("Resume:\n\(profile.resumeText)") }
        return parts.joined(separator: "\n\n")
    }
}
