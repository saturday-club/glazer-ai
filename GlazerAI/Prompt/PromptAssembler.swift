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
    ///
    /// Claude is instructed to:
    /// 1. Extract the person's identity from the OCR text.
    /// 2. Web-search them to gather research beyond the screenshot.
    /// 3. Generate a personalised, genuine ice-breaker (≤ 300 chars).
    /// 4. Return everything as strict JSON — no markdown, no prose outside JSON.
    static let defaultTemplate: String = """
    You are a professional research assistant and outreach specialist. Your task is to research a LinkedIn profile and craft a personalised connection note.

    ## SENDER (the person sending the connection request)
    {candidate_profile}

    ## INSTRUCTIONS

    **Step 1 -- Extract profile from OCR text**
    Parse the OCR text below to identify the target person's: name, headline, company, location, connections count, about section, experience, education, and skills.

    **Step 2 -- Web research**
    Use web_search to find additional information about this person beyond what is in the screenshot. Search for:
    - Recent articles, blog posts, or interviews they have published or appeared in
    - Open-source projects or GitHub activity
    - Conference talks, podcasts, or public appearances
    - Company news or product launches they are associated with
    - Notable professional achievements or recognition

    **Step 3 -- Generate ice-breaker**
    Write a LinkedIn connection note from the sender to the target.

    Hard constraints:
    - 300 characters or fewer (LinkedIn's limit)
    - Reference something SPECIFIC about the target (a project, post, talk, or shared interest)
    - Mention a genuine reason for connecting based on the sender's background
    - No emojis

    Anti-slop rules (the note MUST follow all of these):
    - No throat-clearing openers ("Here's the thing", "I came across", "I noticed that")
    - No adverbs (no -ly words, no "really", "just", "genuinely", "truly", "deeply")
    - No business jargon ("navigate", "landscape", "lean into", "deep dive", "double down", "game-changer")
    - No vague emphasis ("This matters because", "Make no mistake", "Full stop")
    - No binary contrasts ("Not X, but Y" or "It's not about X, it's about Y")
    - No false agency (objects doing human actions: "your work caught my eye", "your post resonated")
    - Active voice only. The sender does something; the target did something. Name the actors.
    - No performative sincerity ("I promise", "genuinely", "honestly", "I have to say")
    - No filler phrases ("At its core", "When it comes to", "It's worth noting", "At the end of the day")
    - State the reason for connecting directly. No rhetorical buildup.
    - Vary sentence lengths. Two short sentences beat one long one stuffed with clauses.
    - If it sounds like a template, rewrite it. If it sounds like every other LinkedIn message, rewrite it.

    Good ice-breaker example:
    "Read your SIGMOD paper on learned indexes. I'm building something similar for time-series at Acme. Would like to compare notes."

    Bad ice-breaker example (do NOT write like this):
    "I came across your truly impressive profile and I'm genuinely excited about the innovative work you're doing in the AI landscape. I'd love to connect and explore potential synergies!"

    **Step 4 -- Return JSON**
    Respond with ONLY valid JSON. No markdown fences. No text before or after the JSON.

    The summary and companyContext fields follow the same anti-slop rules above. Write plain, direct sentences. No filler, no jargon, no adverbs.

    If the OCR text does NOT contain a LinkedIn profile, return:
    {"status":"no_profile_found","profile":null,"research":null,"iceBreakerNote":null,"summary":null,"message":"The captured text does not appear to contain a LinkedIn profile."}

    If the OCR text DOES contain a LinkedIn profile, return:
    {
      "status": "success",
      "profile": {
        "name": "...",
        "headline": "...",
        "company": "...",
        "location": "...",
        "connections": "...",
        "about": "...",
        "experience": ["..."],
        "education": ["..."],
        "skills": ["..."]
      },
      "research": {
        "recentActivity": ["brief description of each finding"],
        "publications": ["title or description"],
        "companyContext": "1-2 sentences about their company, plain language, no jargon",
        "conversationAngles": ["specific angle 1", "specific angle 2"]
      },
      "iceBreakerNote": "The connection note, max 300 chars, anti-slop rules enforced",
      "summary": "2-3 direct sentences about who this person is. No filler, no adverbs.",
      "message": null
    }

    Use null for any field that cannot be determined.

    ## OCR TEXT FROM SCREENSHOT
    {ocr_text}
    """
    // swiftlint:enable line_length

    static let jobDescriptionPlaceholder = "{job_description}"
    static let profileSummaryPlaceholder = "{profile_summary}"

    // swiftlint:disable line_length
    static let iceBreakerRefinementTemplate: String = """
    Rewrite the LinkedIn connection note to align with the job description below.

    ## SENDER
    {candidate_profile}

    ## TARGET PROFILE SUMMARY
    {profile_summary}

    ## JOB DESCRIPTION
    {job_description}

    ## RULES
    - 300 characters or fewer
    - Reference something specific from their background that relates to the job description
    - No emojis

    ## ANTI-SLOP (mandatory)
    - No adverbs (no -ly words, no "really", "just", "genuinely", "truly")
    - No throat-clearing ("I came across", "I noticed that", "I was impressed by")
    - No business jargon ("navigate", "landscape", "lean into", "synergies", "game-changer")
    - No false agency ("your work resonated", "your post caught my eye")
    - No performative sincerity ("I promise", "genuinely", "honestly")
    - No binary contrasts ("Not X, but Y")
    - Active voice only. Name who does what.
    - State the reason for connecting directly. No rhetorical buildup.
    - If it sounds like a template, rewrite it.

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
