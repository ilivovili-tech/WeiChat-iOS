
import SwiftUI
import Combine
import Foundation
import FoundationModels

@MainActor
final class WeiChatAIManager: ObservableObject {

    @Published private(set) var isAvailable = false
    @Published private(set) var status = "正在检查本地 AI..."
    @Published private(set) var isResponding = false

    private let model = SystemLanguageModel.default

    private lazy var session: LanguageModelSession = {
        LanguageModelSession(
            instructions: """
            你是 WeiChat 的 AI 助手。
            请优先使用简体中文回答。
            语气自然、友好、有帮助。
            尽量准确、清楚地回答问题。
            不确定的事情要诚实说明，不要编造事实。
            """
        )
    }()

    func checkAvailability() {
        if model.availability == .available {
            isAvailable = true
            status = "本地 AI 已就绪"
        } else {
            isAvailable = false
            status = "本地 AI 暂不可用，请检查 Apple Intelligence 设置和模型下载状态。"
        }
    }

    func send(text: String) async throws -> String {

        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty else {
            throw NSError(
                domain: "WeiChatAI",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "请输入消息。"
                ]
            )
        }

        guard !isResponding else {
            throw NSError(
                domain: "WeiChatAI",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "AI 正在回答，请稍候。"
                ]
            )
        }

        checkAvailability()

        guard isAvailable else {
            throw NSError(
                domain: "WeiChatAI",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: status
                ]
            )
        }

        isResponding = true
        defer {
            isResponding = false
        }

        let response = try await session.respond(to: prompt)

        return response.content
    }
}
