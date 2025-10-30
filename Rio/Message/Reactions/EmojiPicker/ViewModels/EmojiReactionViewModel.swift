//
//  EmojiReactionViewModel.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/23/25.
//

import Foundation
import FoundationModels
import SwiftUI

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
        guard !isRunningInPreview else { return nil }
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

        let activeProvider = provider
        let requestStart = Date()
        isLoading = true
        errorMessage = nil
        finalists = []

        let trimmedContext = context.flatMap { trimContext($0, maxChars: 300) }
        if let trimmedContext {
            logPromptMetrics("Conversation context", text: trimmedContext)
        }

        switch activeProvider {
        case .apple:
            await runApplePipeline(trimmedText: trimmedText, trimmedContext: trimmedContext)
        case .openai:
            await runOpenAIPipeline(trimmedText: trimmedText, trimmedContext: trimmedContext)
        case .claude:
            await runClaudePipeline(trimmedText: trimmedText, trimmedContext: trimmedContext)
        }

        let totalElapsed = Date().timeIntervalSince(requestStart)
        log(String(format: "⏱️ Request finished in %.2fs using %@", totalElapsed, activeProvider.rawValue))

        isLoading = false
    }

    private func runApplePipeline(trimmedText: String, trimmedContext: String?) async {
        log("\n⚙️ Apple fast emoji pipeline requested for input length \(trimmedText.count) characters")
        guard let fastModel else {
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
            log("🎯 Final finalists: \(fastEmojis.map(\.character).joined(separator: ", "))")
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
            log("🎯 Final finalists: \(openAIEmojis.map(\.character).joined(separator: ", "))")
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

    private func runClaudePipeline(trimmedText: String, trimmedContext: String?) async {
        log("\n🟣 Claude emoji pipeline requested for input length \(trimmedText.count) characters")
        do {
            let claudeEmojis = try await claudeSelectFinalists(text: trimmedText, context: trimmedContext)
            finalists = claudeEmojis
            log("✅ Claude pipeline complete! Found \(claudeEmojis.count) finalists")
            log("🎯 Final finalists: \(claudeEmojis.map(\.character).joined(separator: ", "))")
        } catch {
            let tone = detectTone(for: trimmedText)
            let fallback = fallbackFinalists(for: tone)
            if fallback.isEmpty {
                errorMessage = "Emoji reactions are temporarily unavailable (\(error.localizedDescription))"
            } else {
                finalists = fallback
                errorMessage = "Showing quick emoji suggestions while Claude catches up."
            }

            log("⚠️ Claude pipeline error: \(error)")
        }
    }

    // MARK: - Fast Pipeline

    private func fastSelectFinalists(text: String, model: SystemLanguageModel) async throws -> [Emoji] {
        try await fastSelectFinalists(text: text, context: nil, model: model)
    }

    private func fastSelectFinalists(
        text: String,
        context: String?,
        model: SystemLanguageModel
    ) async throws -> [Emoji] {
        let tone = detectTone(for: text)
        var bestResolved: [Emoji] = []
        log("   🧭 Detected tone: \(tone)")
        log("   🎯 Target finalists: \(fastEmojiTargetCount)")

        for attempt in 0 ..< 3 {
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
                log("   🎉 Finalists selected: \(finalists.map(\.character).joined(separator: ", "))")
                return finalists
            }
        }

        if bestResolved.isEmpty {
            log("   ⚠️ Fast pipeline could not obtain valid emoji suggestions")
        } else if bestResolved.count < fastEmojiTargetCount {
            log("   ⚠️ Fast pipeline resolved only \(bestResolved.count) of \(fastEmojiTargetCount) emoji")
        }

        let finalists = Array(bestResolved.prefix(fastEmojiTargetCount))
        log("   🎉 Finalists selected after retries: \(finalists.map(\.character).joined(separator: ", "))")
        return finalists
    }

    // MARK: - OpenAI Pipeline

    private func openAISelectFinalists(text: String, context: String?) async throws -> [Emoji] {
        let tone = detectTone(for: text)
        var bestResolved: [Emoji] = []
        log("   🧭 (OpenAI) Detected tone: \(tone)")
        log("   🎯 (OpenAI) Target finalists: \(fastEmojiTargetCount)")

        for attempt in 0 ..< 3 {
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

            log(
                "   📊 (OpenAI) Attempt \(attempt + 1) resolved \(resolved.count) emoji from \(suggestions.count) suggestions"
            )

            if !resolved.isEmpty {
                bestResolved = resolved
            }

            if resolved.count >= fastEmojiTargetCount {
                log("   ✅ (OpenAI) Attempt \(attempt + 1) met target with \(resolved.count) emoji")
                let finalists = resolved.count > fastEmojiTargetCount
                    ? Array(resolved.prefix(fastEmojiTargetCount))
                    : resolved
                log("   🎉 (OpenAI) Finalists selected: \(finalists.map(\.character).joined(separator: ", "))")
                return finalists
            }
        }

        if bestResolved.isEmpty {
            log("   ⚠️ (OpenAI) Pipeline could not obtain valid emoji suggestions")
        } else if bestResolved.count < fastEmojiTargetCount {
            log("   ⚠️ (OpenAI) Resolved only \(bestResolved.count) of \(fastEmojiTargetCount) emoji")
        }

        let finalists = Array(bestResolved.prefix(fastEmojiTargetCount))
        log("   🎉 (OpenAI) Finalists selected after retries: \(finalists.map(\.character).joined(separator: ", "))")
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
            let content = try await OpenAIEmojiAPI.sendCompletion(
                systemPrompt: systemPrompt,
                userPrompt: promptText,
                schema: EmojiReactionSchema.openAI,
                errorDomain: "EmojiReactionViewModel"
            )

            let elapsed = Date().timeIntervalSince(start)
            log(String(format: "   ⏱️ (OpenAI) Responded in %.2fs", elapsed))
            guard let data = content.data(using: String.Encoding.utf8) else {
                throw NSError(
                    domain: "EmojiReactionViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI content encoding"]
                )
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

    // MARK: - Claude Pipeline

    private func claudeSelectFinalists(text: String, context: String?) async throws -> [Emoji] {
        let tone = detectTone(for: text)
        var bestResolved: [Emoji] = []
        log("   🧭 (Claude) Detected tone: \(tone)")
        log("   🎯 (Claude) Target finalists: \(fastEmojiTargetCount)")

        for attempt in 0 ..< 3 {
            let suggestions = try await requestClaudeSuggestions(
                text: text,
                context: context,
                tone: tone,
                attempt: attempt
            )

            let resolved = resolveFastSuggestions(
                suggestions,
                tone: tone
            )

            log(
                "   📊 (Claude) Attempt \(attempt + 1) resolved \(resolved.count) emoji from \(suggestions.count) suggestions"
            )

            if !resolved.isEmpty {
                bestResolved = resolved
            }

            if resolved.count >= fastEmojiTargetCount {
                log("   ✅ (Claude) Attempt \(attempt + 1) met target with \(resolved.count) emoji")
                let finalists = resolved.count > fastEmojiTargetCount
                    ? Array(resolved.prefix(fastEmojiTargetCount))
                    : resolved
                log("   🎉 (Claude) Finalists selected: \(finalists.map(\.character).joined(separator: ", "))")
                return finalists
            }
        }

        if bestResolved.isEmpty {
            log("   ⚠️ (Claude) Pipeline could not obtain valid emoji suggestions")
        } else if bestResolved.count < fastEmojiTargetCount {
            log("   ⚠️ (Claude) Resolved only \(bestResolved.count) of \(fastEmojiTargetCount) emoji")
        }

        let finalists = Array(bestResolved.prefix(fastEmojiTargetCount))
        log("   🎉 (Claude) Finalists selected after retries: \(finalists.map(\.character).joined(separator: ", "))")
        return finalists
    }

    private func requestClaudeSuggestions(
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

        logPromptMetrics("(Claude) System prompt", text: systemPrompt)
        logPromptMetrics("(Claude) User prompt", text: promptText)

        let start = Date()
        do {
            log("   🚀 (Claude) Calling Claude (attempt \(attempt + 1))")
            let content = try await sendClaudeCompletion(
                systemPrompt: systemPrompt,
                userPrompt: promptText
            )

            let elapsed = Date().timeIntervalSince(start)
            log(String(format: "   ⏱️ (Claude) Responded in %.2fs", elapsed))

            // Extract JSON from the response (Claude might add extra text)
            let cleanedContent = extractJSON(from: content)

            guard let data = cleanedContent.data(using: String.Encoding.utf8) else {
                throw NSError(
                    domain: "EmojiReactionViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid Claude content encoding"]
                )
            }

            let decoded = try JSONDecoder().decode(ClaudeEmojiReactionResponse.self, from: data)
            let suggestions = decoded.suggestions.map { s in
                FastEmojiSuggestion(character: s.character)
            }

            logSuggestions(suggestions, attempt: attempt)
            return suggestions
        } catch {
            log("   ❌ (Claude) Error on attempt \(attempt + 1): \(error)")
            throw error
        }
    }

    // MARK: - Claude HTTP Helper

    private func sendClaudeCompletion(
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !apiKey.isEmpty else {
            throw NSError(
                domain: "EmojiReactionViewModel",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "CLAUDE_API_KEY environment variable not set"]
            )
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        // Add JSON formatting instruction to the user prompt
        let jsonFormattedPrompt = """
        \(userPrompt)

        IMPORTANT: Return ONLY valid JSON with no additional text, explanation, or commentary before or after. The response must be exactly this structure with nothing else:
        {
          "suggestions": [
            {"character": "emoji1"},
            {"character": "emoji2"},
            {"character": "emoji3"},
            {"character": "emoji4"},
            {"character": "emoji5"},
            {"character": "emoji6"}
          ]
        }

        Do not include markdown code blocks, backticks, or any other formatting. Just the raw JSON object.
        """

        let payload: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": jsonFormattedPrompt]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "EmojiReactionViewModel",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from Claude"]
            )
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw NSError(
                domain: "EmojiReactionViewModel",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Claude HTTP \(httpResponse.statusCode): \(body)"]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String
        else {
            throw NSError(
                domain: "EmojiReactionViewModel",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse Claude content"]
            )
        }

        return text
    }

    private func fallbackFinalists(for tone: FastFallbackTone) -> [Emoji] {
        let characters: [String] = switch tone {
        case .grief:
            ["🤍", "🙏", "🕯️", "💐", "😟"]
        case .celebration:
            ["🎉", "🥳", "🎊", "🎈", "👏", "🎁"]
        case .question:
            ["👍", "👎", "🤔", "❓", "💭", "💡"]
        case .sadness:
            ["😢", "🤗", "💙", "🙏", "💌", "🫂"]
        case .anger:
            ["😡", "😤", "🤬", "💢", "😠", "🙄"]
        case .love:
            ["❤️", "🥰", "😘", "😍", "💞", "💘"]
        case .surprise:
            ["😮", "🤯", "😲", "😳", "❗", "👀"]
        case .worried:
            ["😟", "😰", "😥", "😬", "🙏", "🤞"]
        case .playful:
            ["😜", "😉", "😆", "🤪", "😂", "🎉"]
        case .happy:
            ["😊", "😄", "🥰", "🌟", "👍", "😁"]
        case .sick:
            ["🤒", "🤢", "🤧", "😷", "🤕", "🫶"]
        case .tired:
            ["😴", "🥱", "😪", "💤", "☕", "😌"]
        case .sexy:
            ["😏", "🔥", "😉", "😘", "💋", "😍"]
        case .acknowledgement:
            ["👍", "👎", "✅", "👌", "🤝", "🙏"]
        case .neutral:
            ["😊", "👍", "🤝", "🌟", "💡", "🎯"]
        }

        let catalog = EmojiAIService.getAllEmojis()
        return characters.map { character in
            if let emoji = catalog.first(where: { $0.character == character }) {
                emoji
            } else {
                makeFallbackEmoji(character: character, name: "")
            }
        }
    }

    let systemPrompt = EmojiReactionPrompt.system

    private func requestFastSuggestions(
        text: String,
        context: String?,
        tone: FastFallbackTone,
        attempt: Int,
        model: SystemLanguageModel
    ) async throws -> [FastEmojiSuggestion] {
        let temperature = 0.4
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
            log(
                "   🚀 Calling fast model (attempt \(attempt + 1)) with includeSchemaInPrompt=\(config.includeSchemaInPrompt)"
            )
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

                log(
                    "   ⚠️ Received exceededContextWindowSize on attempt \(attempt + 1); retrying with compact prompt and includeSchemaInPrompt=false"
                )
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
        var prompt = switch variant {
        case .standard:
            """
            last_message: "\(message)"
            tone_hint: \(toneHint)
            Return six emoji suggestions as emoji glyphs only (character). Avoid duplicates. Base the reaction primarily on last_message, but consider conversation_context if provided.
            """
        case .minimal:
            """
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

            When the message is a question and the tone allows, include both 👍 and 👎 among the six reactions so the receiver can signal agreement or disagreement. Skip them only if they would be very inappropriate for the context.
            """
        } else if tone == .acknowledgement {
            prompt += """

            When the message shares a plan or status update, include 👍 to acknowledge it. Offer 👎 only if expressing gentle disagreement would not be insensitive.
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

        log("   🏁 Accepted \(results.count) emoji: \(results.map(\.character).joined(separator: ", "))")
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
            false // handled by dedicated instructions
        case .grief, .sadness, .anger, .sick, .tired, .worried, .sexy:
            false
        default:
            true
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
                "👏", "💃", "🕺", "🔥", "👍", "👎", "🪦", "🖤", "⚰️", "⚱️", "🤗", "🤝", "🤑", "🤓", "👻", "👹", "👽", "👾"
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

    private func extractJSON(from text: String) -> String {
        // Try to find JSON object in the text
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}")
        else {
            return text
        }

        let jsonCandidate = String(text[startIndex ... endIndex])

        // Validate it's actually JSON
        if let data = jsonCandidate.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return jsonCandidate
        }

        return text
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
            "grief, condolences, comfort, emotional support"
        case .celebration:
            "celebration, excitement, good news, congratulations"
        case .question:
            "questions, uncertainty, seeking guidance or help; include thumbs up/down if appropriate"
        case .sadness:
            "sadness or feeling low; offer gentle empathy and support"
        case .anger:
            "anger or frustration; acknowledge the feeling without escalating"
        case .love:
            "love, affection, romantic energy; respond with warmth"
        case .surprise:
            "surprise or amazement; reflect astonishment or curiosity"
        case .worried:
            "worry, anxiety, nervous energy; favor calming reassurance"
        case .playful:
            "playfulness, teasing, light jokes; keep it fun"
        case .happy:
            "general happiness or good mood; celebrate with upbeat reactions"
        case .sick:
            "illness or not feeling well; show care and sympathy"
        case .tired:
            "tiredness or exhaustion; respond with rest encouragement"
        case .sexy:
            "flirty or intimate tone; keep reactions tasteful and playful"
        case .acknowledgement:
            "status update or plan; include a thumbs up acknowledgement when it fits"
        case .neutral:
            "neutral or mixed tone; pick broadly useful reactions"
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
