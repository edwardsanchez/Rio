//
//  EmojiReactionViewModel.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/23/25.
//

import Foundation
import SwiftUI
import FoundationModels
// OpenAI integration helper lives in: OpenAI Example/OpenAI.swift

@MainActor
@Observable
class EmojiReactionViewModel {
    var inputText: String = "I'm pregnant"
    var finalists: [Emoji] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var provider: EmojiProvider = .openai

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static let previewFinalists: [Emoji] = [
        Emoji(id: "preview_smile", character: "😊", name: "Warm Smile", category: .frequentlyUsed),
        Emoji(id: "preview_party", character: "🥳", name: "Party Time", category: .frequentlyUsed),
        Emoji(id: "preview_idea", character: "💡", name: "Bright Idea", category: .frequentlyUsed),
        Emoji(id: "preview_thumbsup", character: "👍", name: "Great Job", category: .frequentlyUsed),
        Emoji(id: "preview_rocket", character: "🚀", name: "Full Speed", category: .frequentlyUsed),
        Emoji(id: "preview_confetti", character: "🎉", name: "Celebrate", category: .frequentlyUsed)
    ]
    
    private let fastEmojiTargetCount = 6
    private let maxInputLength = 512
    private let enableDebugLogs = true
    private let fastModel: SystemLanguageModel?

    init(fastModel: SystemLanguageModel? = nil) {
        self.fastModel = fastModel ?? Self.initializeFastModel()
        if Self.isRunningInPreview {
            finalists = Self.previewFinalists
        }
    }

    private static func initializeFastModel() -> SystemLanguageModel? {
        guard !Self.isRunningInPreview else { return nil }
        return SystemLanguageModel()
    }

    // MARK: - Main Pipeline
    
    func findEmojis(for text: String) async {
        await findEmojis(for: text, context: nil)
    }

    func findEmojis(for text: String, context: String?) async {
        guard !text.isEmpty else {
            errorMessage = "Please enter some text"
            return
        }

        let trimmedText = trimmedInput(for: text)
        if trimmedText.count != text.count {
            log("✂️ Input truncated from \(text.count) to \(trimmedText.count) characters to cap prompt size")
        }

        isLoading = true
        errorMessage = nil
        finalists = []

        let trimmedContext = context.flatMap { trimContext($0, maxChars: 300) }
        if let trimmedContext {
            logPromptMetrics("Conversation context", text: trimmedContext)
        }

        switch provider {
        case .apple:
            await runApplePipeline(trimmedText: trimmedText, trimmedContext: trimmedContext)
        case .openai:
            await runOpenAIPipeline(trimmedText: trimmedText, trimmedContext: trimmedContext)
        }

        isLoading = false
    }

    private func runApplePipeline(trimmedText: String, trimmedContext: String?) async {
        log("\n⚙️ Apple fast emoji pipeline requested for input length \(trimmedText.count) characters")
        guard let fastModel = fastModel else {
            errorMessage = "Emoji reactions require the on-device language model, which isn't available in previews."
            log("ℹ️ Fast model unavailable – likely running inside previews or unsupported platform.")
            return
        }
        log("ℹ️ Fast model use case: general")
        log("ℹ️ Fast model availability: \(fastModel.availability)")
        guard fastModel.isAvailable else {
            errorMessage = "Fast emoji model is not available"
            return
        }
        do {
            log("⚡️ Running fast emoji reaction pipeline for: '\(trimmedText)'")
            let fastEmojis = try await fastSelectFinalists(text: trimmedText, context: trimmedContext, model: fastModel)
            finalists = fastEmojis
            log("✅ Fast pipeline complete! Found \(fastEmojis.count) finalists")
            log("🎯 Final finalists: \(fastEmojis.map { $0.character }.joined(separator: ", "))")
        } catch {
            let tone = detectTone(for: trimmedText)
            let fallback = fallbackFinalists(for: tone)
            if fallback.isEmpty {
                errorMessage = "Emoji reactions are temporarily unavailable (\(error.localizedDescription))"
            } else {
                finalists = fallback
                errorMessage = "Showing quick emoji suggestions while Apple Intelligence catches up."
            }
            log("⚠️ Fast pipeline error: \(error)")
        }
    }

    private func runOpenAIPipeline(trimmedText: String, trimmedContext: String?) async {
        log("\n🔵 OpenAI emoji pipeline requested for input length \(trimmedText.count) characters")
        do {
            let openAIEmojis = try await openAISelectFinalists(text: trimmedText, context: trimmedContext)
            finalists = openAIEmojis
            log("✅ OpenAI pipeline complete! Found \(openAIEmojis.count) finalists")
            log("🎯 Final finalists: \(openAIEmojis.map { $0.character }.joined(separator: ", "))")
        } catch {
            let tone = detectTone(for: trimmedText)
            let fallback = fallbackFinalists(for: tone)
            if fallback.isEmpty {
                errorMessage = "Emoji reactions are temporarily unavailable (\(error.localizedDescription))"
            } else {
                finalists = fallback
                errorMessage = "Showing quick emoji suggestions while OpenAI catches up."
            }
            log("⚠️ OpenAI pipeline error: \(error)")
        }
    }
    
    // MARK: - Fast Pipeline
    
    private func fastSelectFinalists(text: String, model: SystemLanguageModel) async throws -> [Emoji] {
        return try await fastSelectFinalists(text: text, context: nil, model: model)
    }

    private func fastSelectFinalists(text: String, context: String?, model: SystemLanguageModel) async throws -> [Emoji] {
        let tone = detectTone(for: text)
        var bestResolved: [Emoji] = []
        log("   🧭 Detected tone: \(tone)")
        log("   🎯 Target finalists: \(fastEmojiTargetCount)")
        
        for attempt in 0..<3 {
            let suggestions = try await requestFastSuggestions(
                text: text,
                context: context,
                tone: tone,
                attempt: attempt,
                model: model
            )
            let resolved = resolveFastSuggestions(
                suggestions,
                tone: tone
            )
            log("   📊 Attempt \(attempt + 1) resolved \(resolved.count) emoji from \(suggestions.count) suggestions")
            
            if !resolved.isEmpty {
                bestResolved = resolved
            }
            
            if resolved.count >= fastEmojiTargetCount {
                log("   ✅ Attempt \(attempt + 1) met target with \(resolved.count) emoji")
                let finalists = resolved.count > fastEmojiTargetCount
                    ? Array(resolved.prefix(fastEmojiTargetCount))
                    : resolved
                log("   🎉 Finalists selected: \(finalists.map { $0.character }.joined(separator: ", "))")
                return finalists
            }
        }
        
        if bestResolved.isEmpty {
            log("   ⚠️ Fast pipeline could not obtain valid emoji suggestions")
        } else if bestResolved.count < fastEmojiTargetCount {
            log("   ⚠️ Fast pipeline resolved only \(bestResolved.count) of \(fastEmojiTargetCount) emoji")
        }
        
        let finalists = Array(bestResolved.prefix(fastEmojiTargetCount))
        log("   🎉 Finalists selected after retries: \(finalists.map { $0.character }.joined(separator: ", "))")
        return finalists
    }

    // MARK: - OpenAI Pipeline

    private func openAISelectFinalists(text: String, context: String?) async throws -> [Emoji] {
        let tone = detectTone(for: text)
        var bestResolved: [Emoji] = []
        log("   🧭 (OpenAI) Detected tone: \(tone)")
        log("   🎯 (OpenAI) Target finalists: \(fastEmojiTargetCount)")

        for attempt in 0..<3 {
            let suggestions = try await requestOpenAISuggestions(
                text: text,
                context: context,
                tone: tone,
                attempt: attempt
            )
            let resolved = resolveFastSuggestions(
                suggestions,
                tone: tone
            )
            log("   📊 (OpenAI) Attempt \(attempt + 1) resolved \(resolved.count) emoji from \(suggestions.count) suggestions")

            if !resolved.isEmpty {
                bestResolved = resolved
            }

            if resolved.count >= fastEmojiTargetCount {
                log("   ✅ (OpenAI) Attempt \(attempt + 1) met target with \(resolved.count) emoji")
                let finalists = resolved.count > fastEmojiTargetCount
                    ? Array(resolved.prefix(fastEmojiTargetCount))
                    : resolved
                log("   🎉 (OpenAI) Finalists selected: \(finalists.map { $0.character }.joined(separator: ", "))")
                return finalists
            }
        }

        if bestResolved.isEmpty {
            log("   ⚠️ (OpenAI) Pipeline could not obtain valid emoji suggestions")
        } else if bestResolved.count < fastEmojiTargetCount {
            log("   ⚠️ (OpenAI) Resolved only \(bestResolved.count) of \(fastEmojiTargetCount) emoji")
        }

        let finalists = Array(bestResolved.prefix(fastEmojiTargetCount))
        log("   🎉 (OpenAI) Finalists selected after retries: \(finalists.map { $0.character }.joined(separator: ", "))")
        return finalists
    }

    private func requestOpenAISuggestions(
        text: String,
        context: String?,
        tone: FastFallbackTone,
        attempt: Int
    ) async throws -> [FastEmojiSuggestion] {
        let config = requestConfiguration(for: attempt)
        let toneHint = toneHint(for: tone)
        let promptText = fastUserPrompt(
            message: text,
            context: context,
            tone: tone,
            toneHint: toneHint,
            attempt: attempt,
            variant: config.variant
        )

        logPromptMetrics("(OpenAI) System prompt", text: systemPrompt)
        logPromptMetrics("(OpenAI) User prompt", text: promptText)

        let start = Date()
        do {
            log("   🚀 (OpenAI) Calling OpenAI (attempt \(attempt + 1))")
            let content = try await sendOpenAICompletion(
                systemPrompt: systemPrompt,
                userPrompt: promptText,
                schema: openAIResponseSchema()
            )
            let elapsed = Date().timeIntervalSince(start)
            log(String(format: "   ⏱️ (OpenAI) Responded in %.2fs", elapsed))
            guard let data = content.data(using: String.Encoding.utf8) else {
                throw NSError(domain: "EmojiReactionViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI content encoding"])
            }
            let decoded = try JSONDecoder().decode(OpenAIEmojiReactionResponse.self, from: data)
            let suggestions = decoded.suggestions.map { s in
                FastEmojiSuggestion(character: s.character)
            }
            logSuggestions(suggestions, attempt: attempt)
            return suggestions
        } catch {
            log("   ❌ (OpenAI) Error on attempt \(attempt + 1): \(error)")
            throw error
        }
    }

    private func openAIResponseSchema() -> [String: Any] {
        [
            "name": "emoji_reaction_response",
            "schema": [
                "type": "object",
                "properties": [
                    "suggestions": [
                        "type": "array",
                        "minItems": 6,
                        "maxItems": 6,
                        "items": [
                            "type": "object",
                            "properties": [
                                "character": ["type": "string"]
                            ],
                            "required": ["character"],
                            "additionalProperties": false
                        ]
                    ]
                ],
                "required": ["suggestions"],
                "additionalProperties": false
            ]
        ]
    }

    // MARK: - OpenAI HTTP Helper
    private func sendOpenAICompletion(
        systemPrompt: String,
        userPrompt: String,
        schema: [String: Any]
    ) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw NSError(domain: "EmojiReactionViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "OPENAI_API_KEY environment variable not set"])
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let payload: [String: Any] = [
            "model": "gpt-5-nano-2025-08-07",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": schema
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "EmojiReactionViewModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw NSError(domain: "EmojiReactionViewModel", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI HTTP \(httpResponse.statusCode): \(body)"])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "EmojiReactionViewModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI content"])
        }
        return content
    }

    private func fallbackFinalists(for tone: FastFallbackTone) -> [Emoji] {
        let characters: [String]
        switch tone {
        case .grief:
            characters = ["🤍", "🤗", "🙏", "🕯️", "💐", "🤝"]
        case .celebration:
            characters = ["🎉", "🥳", "🎊", "🎈", "👏", "🎁"]
        case .question:
            characters = ["👍", "👎", "🤔", "❓", "💭", "💡"]
        case .sadness:
            characters = ["😢", "🤗", "💙", "🙏", "💌", "🫂"]
        case .anger:
            characters = ["😡", "😤", "🤬", "💢", "😠", "🙄"]
        case .love:
            characters = ["❤️", "🥰", "😘", "😍", "💞", "💘"]
        case .surprise:
            characters = ["😮", "🤯", "😲", "😳", "❗", "👀"]
        case .worried:
            characters = ["😟", "😰", "😥", "😬", "🙏", "🤞"]
        case .playful:
            characters = ["😜", "😉", "😆", "🤪", "😂", "🎉"]
        case .happy:
            characters = ["😊", "😄", "🥰", "🌟", "👍", "😁"]
        case .sick:
            characters = ["🤒", "🤢", "🤧", "😷", "🤕", "🫶"]
        case .tired:
            characters = ["😴", "🥱", "😪", "💤", "☕", "😌"]
        case .sexy:
            characters = ["😏", "🔥", "😉", "😘", "💋", "😍"]
        case .acknowledgement:
            characters = ["👍", "👎", "✅", "👌", "🤝", "🙏"]
        case .neutral:
            characters = ["😊", "👍", "🤝", "🌟", "💡", "🎯"]
        }

        let catalog = EmojiAIService.getAllEmojis()
        return characters.map { character in
            if let emoji = catalog.first(where: { $0.character == character }) {
                return emoji
            } else {
                return makeFallbackEmoji(character: character, name: "")
            }
        }
    }
    
    let systemPrompt = """
        You are a conversation-aware emoji curator specializing in expressive yet thoughtful reactions for chat platforms.
        Your task is to return six emoji suggestions, each with:
        •    character: one emoji glyph (no emoji names, codes, or placeholders)
        
        Organize the reactions from most to least fitting based on the original message. Avoid repeating emojis and ensure reactions respond to the message rather than just mirror the sender’s tone.
        
        Key behavior requirements:
        1.    Be context-sensitive: Avoid 👍/👎 in serious/sensitive moments (e.g., grief, illness).
        2.    Use 👍 and or 👎 when a question is asked, and when doing so would not feel tone-deaf or insensitive.
        3.    If a humorous attempt is detected, include 1–2 laughing emojis near the top of the list.
        4.    Never duplicate emojis within the same list.
        5.    Responses should consider tone_hint (if provided) to guide overall mood and relevance.
        """
    
    private func requestFastSuggestions(
        text: String,
        context: String?,
        tone: FastFallbackTone,
        attempt: Int,
        model: SystemLanguageModel
    ) async throws -> [FastEmojiSuggestion] {
        let temperature: Double = 0.4
        let config = requestConfiguration(for: attempt)
        let toneHint = toneHint(for: tone)
        let promptText = fastUserPrompt(
            message: text,
            context: context,
            tone: tone,
            toneHint: toneHint,
            attempt: attempt,
            variant: config.variant
        )
        
        logPromptMetrics("System prompt", text: systemPrompt)
        logPromptMetrics("User prompt", text: promptText)
        log("   🎚️ Temperature: \(temperature)")
        log("   📦 includeSchemaInPrompt: \(config.includeSchemaInPrompt)")
        
        let session = LanguageModelSession(
            model: model,
            instructions: Instructions(systemPrompt)
        )
        
        let options = GenerationOptions(temperature: temperature)
        let start = Date()
        do {
            log("   🚀 Calling fast model (attempt \(attempt + 1)) with includeSchemaInPrompt=\(config.includeSchemaInPrompt)")
            let response = try await session.respond(
                to: Prompt(promptText),
                generating: FastEmojiReactionResponse.self,
                includeSchemaInPrompt: config.includeSchemaInPrompt,
                options: options
            )
            let elapsed = Date().timeIntervalSince(start)
            log(String(format: "   ⏱️ Fast model responded in %.2fs", elapsed))
            let suggestions = response.content.suggestions
            logSuggestions(suggestions, attempt: attempt)
            return suggestions
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                guard config.includeSchemaInPrompt else {
                    log("   ⚠️ Context window limit hit with minimal prompt; aborting this attempt")
                    return []
                }
                log("   ⚠️ Received exceededContextWindowSize on attempt \(attempt + 1); retrying with compact prompt and includeSchemaInPrompt=false")
                let minimalPrompt = fastUserPrompt(
                    message: text,
                    context: context,
                    tone: tone,
                    toneHint: toneHint,
                    attempt: attempt,
                    variant: .minimal
                )
                logPromptMetrics("Compact prompt", text: minimalPrompt)
                let fallbackSession = LanguageModelSession(
                    model: model,
                    instructions: Instructions(systemPrompt)
                )
                let fallbackStart = Date()
                let response = try await fallbackSession.respond(
                    to: Prompt(minimalPrompt),
                    generating: FastEmojiReactionResponse.self,
                    includeSchemaInPrompt: false,
                    options: options
                )
                let elapsed = Date().timeIntervalSince(fallbackStart)
                log(String(format: "   ⏱️ Fast model retry responded in %.2fs", elapsed))
                let suggestions = response.content.suggestions
                logSuggestions(suggestions, attempt: attempt, isRetry: true)
                return suggestions
            default:
                log("   ❌ Fast model error on attempt \(attempt + 1): \(error)")
                throw error
            }
        } catch {
            log("   ❌ Unexpected fast model error on attempt \(attempt + 1): \(error)")
            throw error
        }
    }
    
    private enum FastPromptVariant {
        case standard
        case minimal
    }

    private struct FastRequestConfiguration {
        let variant: FastPromptVariant
        let includeSchemaInPrompt: Bool
    }

    private func requestConfiguration(for attempt: Int) -> FastRequestConfiguration {
        FastRequestConfiguration(
            variant: attempt == 0 ? .standard : .minimal,
            includeSchemaInPrompt: attempt == 0
        )
    }

    private func fastUserPrompt(
        message: String,
        context: String?,
        tone: FastFallbackTone,
        toneHint: String,
        attempt: Int,
        variant: FastPromptVariant
    ) -> String {
        var prompt: String
        
        switch variant {
        case .standard:
            prompt = """
            last_message: "\(message)"
            tone_hint: \(toneHint)
            Return six emoji suggestions as emoji glyphs only (character). Avoid duplicates. Base the reaction primarily on last_message, but consider conversation_context if provided.
            """
        case .minimal:
            prompt = """
            last_message: "\(message)"
            tone_hint: \(toneHint)
            Provide six emoji suggestions (emoji glyphs only). Use only emoji glyphs; no text, codes, or repeats. Use last_message and consider conversation_context if present.
            """
        }
        
        if let context, !context.isEmpty {
            let escaped = context
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            prompt += "\nconversation_context: \"\(escaped)\""
        }

        if tone == .question {
            prompt += """
            
            When the message is a question and the tone allows, include both 👍 and 👎 among the six reactions so the receiver can signal agreement or disagreement. Skip them only if they would be inappropriate for the context.
            """
        } else if tone == .acknowledgement {
            prompt += """
            
            When the message shares a plan or status update, include 👍 to acknowledge it. Offer 👎 only if expressing gentle disagreement would be considerate.
            """
        } else if encouragesThumbsUp(for: tone) {
            prompt += """
            
            Include 👍 when it feels like a warm acknowledgement and won't come across as tone-deaf.
            """
        }
        
        switch attempt {
        case 1:
            prompt += "\nReminder: return six unique emoji glyphs only (e.g. 😄 🤰 👶 👍 👎 ❤️)."
        case 2:
            prompt += "\nFinal attempt: six unique emoji glyphs only."
        default:
            break
        }
        
        return prompt
    }

    private func logSuggestions(
        _ suggestions: [FastEmojiSuggestion],
        attempt: Int,
        isRetry: Bool = false
    ) {
        let attemptLabel = isRetry ? "retry" : "attempt"
        log("   ⚡️ Fast model returned \(suggestions.count) suggestions (\(attemptLabel) \(attempt + 1)):")
        for (index, suggestion) in suggestions.enumerated() {
            log("     \(index + 1). \(suggestion.character)")
        }
    }

    private func resolveFastSuggestions(
        _ suggestions: [FastEmojiSuggestion],
        tone: FastFallbackTone
    ) -> [Emoji] {
        let allEmojis = EmojiAIService.getAllEmojis()
        var seenCharacters: Set<String> = []
        var results: [Emoji] = []
        log("   🔍 Evaluating \(suggestions.count) suggestions against tone \(tone)")
        
        for (index, suggestion) in suggestions.enumerated() {
            log("     ➡️ Suggestion \(index + 1): '\(suggestion.character)'")
            guard let emoji = normalizedEmoji(
                from: suggestion,
                using: allEmojis,
                index: index,
                seenCharacters: &seenCharacters,
                tone: tone
            ) else {
                continue
            }
            
            results.append(emoji)
            
            if results.count == fastEmojiTargetCount {
                break
            }
        }
        
        log("   🏁 Accepted \(results.count) emoji: \(results.map { $0.character }.joined(separator: ", "))")
        return results
    }
    
    private func makeFallbackEmoji(character: String, name: String) -> Emoji {
        let scalarId = character.unicodeScalars
            .map { String(format: "%04X", $0.value) }
            .joined(separator: "_")
        let fallbackId = "fast_\(scalarId)"
        let fallbackName = name.isEmpty ? "" : name
        
        return Emoji(
            id: fallbackId,
            character: character,
            name: fallbackName,
            keywords: [],
            category: .frequentlyUsed
        )
    }
    
    private func normalizedEmoji(
        from suggestion: FastEmojiSuggestion,
        using allEmojis: [Emoji],
        index: Int,
        seenCharacters: inout Set<String>,
        tone: FastFallbackTone
    ) -> Emoji? {
        let trimmedCharacter = suggestion.character.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Enforce a single emoji character only; reject anything else
        guard isSingleEmoji(trimmedCharacter) else {
            log("     ❌ Rejecting suggestion \(index + 1) '\(suggestion.character)' – not a single emoji character")
            return nil
        }

        if shouldRejectSuggestion(character: trimmedCharacter, tone: tone) {
            log("     ❌ Rejecting suggestion \(index + 1) '\(trimmedCharacter)' – blocked for tone \(tone)")
            return nil
        }
        
        if let existing = allEmojis.first(where: { $0.character == trimmedCharacter }) {
            guard !seenCharacters.contains(existing.character) else {
                log("     ⚠️ Skipping suggestion \(index + 1) '\(trimmedCharacter)' – duplicate of accepted emoji")
                return nil
            }
            seenCharacters.insert(existing.character)
            log("     ✅ Accepted suggestion \(index + 1) '\(trimmedCharacter)' – matched catalog emoji \(existing.id)")
            return existing
        } else {
            guard !seenCharacters.contains(trimmedCharacter) else {
                log("     ⚠️ Skipping suggestion \(index + 1) '\(trimmedCharacter)' – duplicate fallback candidate")
                return nil
            }
            seenCharacters.insert(trimmedCharacter)
            // Character is a valid single emoji, but not in our DB — create a fallback entry
            let fallback = makeFallbackEmoji(
                character: trimmedCharacter,
                name: ""
            )
            log("     ✅ Accepted suggestion \(index + 1) '\(trimmedCharacter)' – created fallback emoji \(fallback.id)")
            return fallback
        }
    }
    
    private func trimmedInput(for text: String) -> String {
        if text.count <= maxInputLength {
            return text
        }
        let trimmed = text.prefix(maxInputLength)
        return String(trimmed)
    }

    private func approxTokenCount(for text: String) -> Int {
        max(1, text.count / 4)
    }

    private func logPromptMetrics(
        _ label: String,
        text: String
    ) {
        guard enableDebugLogs else { return }
        log("   🧾 \(label) length: \(text.count) chars (~\(approxTokenCount(for: text)) tokens)")
    }

    private func log(_ message: String) {
        guard enableDebugLogs else { return }
        print(message)
    }

    private func trimContext(_ s: String, maxChars: Int = 300) -> String {
        if s.count <= maxChars { return s }
        return String(s.suffix(maxChars))
    }
    
    private func containsRenderableEmoji(_ string: String) -> Bool {
        string.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
        }
    }
    
    // Removed name/keyword matching: we only accept explicit emoji characters
    
    // Removed tokenization helpers: not needed when enforcing emoji-only
    
    private func encouragesThumbsUp(for tone: FastFallbackTone) -> Bool {
        switch tone {
        case .question, .acknowledgement:
            return false // handled by dedicated instructions
        case .grief, .sadness, .anger, .sick, .tired, .worried, .sexy:
            return false
        default:
            return true
        }
    }
    
    private func shouldRejectSuggestion(
        character: String?,
        tone: FastFallbackTone
    ) -> Bool {
        guard let character else { return false }
        
        switch tone {
        case .grief:
            return [
                "🎉", "🥳", "🎊", "🎈", "🍾", "🍻", "🥂", "🏆",
                "😂", "🤣", "😆", "😜", "😝", "🤪", "😺", "😹",
                "👏", "💃", "🕺", "🔥", "👍", "👎", "🪦", "🖤", "⚰️", "⚱️"
            ].contains(character)
        case .celebration:
            return ["😢", "😭", "💔", "🕯️", "🪦", "🖤", "⚰️", "⚱️"].contains(character)
        case .question:
            return ["🎉", "🥳", "🏆", "🍾", "🎊", "🎈"].contains(character)
        case .sadness, .worried, .sick:
            return ["🎉", "🥳", "🎊", "🎈", "🍾", "🍻", "🥂", "🏆", "👎"].contains(character)
        case .anger:
            return ["🎉", "🥳", "🎊", "🎈", "🍾", "🍻", "🥂", "🏆"].contains(character)
        case .tired:
            return ["🎉", "🥳", "🎊", "🎈", "🍾", "🍻", "🥂", "🏆", "👎"].contains(character)
        default:
            return false
        }
    }

    private func isSingleEmoji(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        // One extended grapheme cluster and it is renderable as emoji
        return string.count == 1 && containsRenderableEmoji(string)
    }
    
    private func detectTone(for text: String) -> FastFallbackTone {
        let lowercased = text.lowercased()
        let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
        
        func containsAny(_ keywords: [String]) -> Bool {
            keywords.contains { lowercased.contains($0) }
        }
        
        let griefKeywords: [String] = [
            "died", "die", "loss", "lost", "passed", "passing", "funeral",
            "condolence", "grief", "heartbroken", "mourning", "sorry for your loss"
        ]
        
        if containsAny(griefKeywords) {
            return .grief
        }
        
        let angerKeywords: [String] = [
            "angry", "mad", "furious", "pissed", "rage", "annoyed", "irritated",
            "frustrated", "livid", "fuming"
        ]
        
        if containsAny(angerKeywords) {
            return .anger
        }
        
        let sadnessKeywords: [String] = [
            "sad", "down", "depressed", "blue", "crying", "cried",
            "lonely", "upset", "miserable", "tearful"
        ]
        
        if containsAny(sadnessKeywords) {
            return .sadness
        }
        
        let worriedKeywords: [String] = [
            "worried", "nervous", "anxious", "concerned", "scared", "afraid",
            "uneasy", "stressed", "panicking", "panicked", "anxiety"
        ]
        
        if containsAny(worriedKeywords) {
            return .worried
        }
        
        let sickKeywords: [String] = [
            "sick", "ill", "illness", "flu", "cold", "fever", "covid",
            "virus", "nauseous", "nausea", "vomit", "vomiting", "doctor",
            "clinic", "medicine"
        ]
        
        if containsAny(sickKeywords) {
            return .sick
        }
        
        let tiredKeywords: [String] = [
            "tired", "exhausted", "sleepy", "worn out", "drained", "beat",
            "fatigued", "burned out", "burnt out"
        ]
        
        if containsAny(tiredKeywords) {
            return .tired
        }
        
        let questionStarts: [String] = [
            "how", "what", "why", "where", "when", "should", "could",
            "would", "is", "are", "did", "do", "can", "will"
        ]
        let questionMarkers: [String] = [
            "?", "any advice", "any ideas", "what do you think",
            "do you think", "thoughts", "opinions"
        ]
        if text.contains("?")
            || questionMarkers.contains(where: { lowercased.contains($0) })
            || questionStarts.contains(where: { trimmed.hasPrefix($0 + " ") }) {
            return .question
        }
        
        let acknowledgementPhrases: [String] = [
            "be right back", "brb", "bbl", "on my way", "omw", "heading out",
            "heading home", "headed home", "headed back", "going home", "go home",
            "going to bed", "go to bed", "going to sleep", "take a shower",
            "taking a shower", "taking a nap", "take a nap", "logging off",
            "signing off", "clocking out", "heading to bed", "going for a walk",
            "go for a walk", "going to the gym", "going to work", "going to class"
        ]
        let acknowledgementPrefixes: [String] = [
            "i'm going to", "im going to", "i am going to",
            "i'm gonna", "im gonna", "i am gonna",
            "i'm heading", "im heading", "i am heading",
            "i'm about to", "im about to", "i am about to",
            "i'm leaving", "im leaving", "i am leaving",
            "i'll be back", "i will be back", "i'll be home", "i will be home",
            "i'll be there", "i will be there", "i'll head", "i will head"
        ]
        
        if containsAny(acknowledgementPhrases)
            || acknowledgementPrefixes.contains(where: { lowercased.contains($0) }) {
            return .acknowledgement
        }
        
        let celebrationKeywords: [String] = [
            "congrats", "congratulations", "awesome", "great", "amazing",
            "promotion", "party", "celebrate", "excited", "stoked", "yay",
            "won", "win", "victory", "birthday", "anniversary"
        ]
        
        if containsAny(celebrationKeywords) {
            return .celebration
        }
        
        let happyKeywords: [String] = [
            "happy", "glad", "joyful", "smiling", "smile", "delighted",
            "pleased", "content", "cheerful"
        ]
        
        if containsAny(happyKeywords) {
            return .happy
        }
        
        let loveKeywords: [String] = [
            "love", "loving", "adore", "beloved", "xoxo", "honey", "sweetheart",
            "crush", "babe", "baby"
        ]
        
        if containsAny(loveKeywords) {
            return .love
        }
        
        let sexyKeywords: [String] = [
            "sexy", "hot", "steamy", "spicy", "thirsty", "thirst trap",
            "nsfw", "horny", "kinky", "sultry"
        ]
        
        if containsAny(sexyKeywords) {
            return .sexy
        }
        
        let surpriseKeywords: [String] = [
            "omg", "wow", "whoa", "surprised", "shocked", "no way",
            "can't believe", "cant believe", "wtf", "holy"
        ]
        
        if containsAny(surpriseKeywords) {
            return .surprise
        }
        
        let playfulKeywords: [String] = [
            "lol", "haha", "hehe", "playful", "kidding", "joking", "jk",
            "teasing", "prank", "funny", "lmao", "lmfao"
        ]
        
        if containsAny(playfulKeywords) {
            return .playful
        }
        
        return .neutral
    }
    
    private func toneHint(for tone: FastFallbackTone) -> String {
        switch tone {
        case .grief:
            return "grief, condolences, comfort, emotional support"
        case .celebration:
            return "celebration, excitement, good news, congratulations"
        case .question:
            return "questions, uncertainty, seeking guidance or help; include thumbs up/down if appropriate"
        case .sadness:
            return "sadness or feeling low; offer gentle empathy and support"
        case .anger:
            return "anger or frustration; acknowledge the feeling without escalating"
        case .love:
            return "love, affection, romantic energy; respond with warmth"
        case .surprise:
            return "surprise or amazement; reflect astonishment or curiosity"
        case .worried:
            return "worry, anxiety, nervous energy; favor calming reassurance"
        case .playful:
            return "playfulness, teasing, light jokes; keep it fun"
        case .happy:
            return "general happiness or good mood; celebrate with upbeat reactions"
        case .sick:
            return "illness or not feeling well; show care and sympathy"
        case .tired:
            return "tiredness or exhaustion; respond with rest encouragement"
        case .sexy:
            return "flirty or intimate tone; keep reactions tasteful and playful"
        case .acknowledgement:
            return "status update or plan; include a thumbs up acknowledgement when it fits"
        case .neutral:
            return "neutral or mixed tone; pick broadly useful reactions"
        }
    }
    
    private enum FastFallbackTone {
        case grief
        case celebration
        case question
        case sadness
        case anger
        case love
        case surprise
        case worried
        case playful
        case happy
        case sick
        case tired
        case sexy
        case acknowledgement
        case neutral
    }
}
