
import Foundation
import FoundationModels
import UIKit

@MainActor
final class WeiChatAIManager: ObservableObject {

    @Published private(set) var isAvailable = false
    @Published private(set) var status = "正在检查本地 AI..."
    @Published private(set) var isResponding = false

    private let model = SystemLanguageModel.default

    private lazy var session = LanguageModelSession(
        instructions: """
        你是 WeiChat AI 助手。
        请使用简体中文回答用户。
        语气自然、友好、有帮助。
        尽量清楚、准确地回答问题。
        如果不知道答案，请诚实说明。
        """
    )

    func checkAvailability() {
        if case .available = model.availability {
            isAvailable = true
            status = "本地 AI 已就绪"
        } else {
            isAvailable = false
            status = "本地 AI 尚未就绪，请检查 Apple Intelligence 设置或模型下载状态。"
        }
    }

    func send(
        text: String,
        image: UIImage?
    ) async throws -> String {

        guard !isResponding else {
            throw NSError(
                domain: "WeiChatAI",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "AI 正在回答，请稍等。"
                ]
            )
        }

        checkAvailability()

        guard isAvailable else {
            throw NSError(
                domain: "WeiChatAI",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: status
                ]
            )
        }

        isResponding = true
        defer { isResponding = false }

        if let image {
            guard let cgImage = image.cgImage else {
                throw NSError(
                    domain: "WeiChatAI",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: "无法读取这张图片。"
                    ]
                )
            }

            if #available(iOS 27.0, *) {
                let response = try await session.respond {
                    text.isEmpty ? "请分析这张图片。" : text
                    Attachment(cgImage)
                }

                return response.content
            } else {
                throw NSError(
                    domain: "WeiChatAI",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey: "图片理解需要 iOS 27 或更新版本。"
                    ]
                )
            }
        } else {
            let response = try await session.respond(to: text)
            return response.content
        }
    }
}
