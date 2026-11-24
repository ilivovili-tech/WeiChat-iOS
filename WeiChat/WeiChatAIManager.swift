
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

    private lazy var session = LanguageModelSession(
        instructions: """
        你是 WeiChat 的 AI 助手。
        请使用简体中文回答。
        语气自然、友好、有帮助。
        尽量准确、清楚地回答问题。
        不确定的事情要诚实说明，不要编造事实。
        """
    )

    func checkAvailability() {

        switch model.availability {

        case .available:
            isAvailable = true
            status = "本地 AI 已就绪"

        case .unavailable(let reason):

            isAvailable = false

            switch reason {

            case .deviceNotEligible:
                status = "设备或当前地区不符合 Apple 本地 AI 使用条件。"

            case .appleIntelligenceNotEnabled:
                status = "请先在设置中开启 Apple Intelligence。"

            case .modelNotReady:
                status = "Apple AI 模型尚未准备完成，请连接 Wi-Fi 并等待下载。"

            @unknown default:
                status = "Apple 本地 AI 暂时不可用，请检查系统设置。"
            }
        }
    }

    func send(text: String) async throws -> String {

        let prompt = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

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
