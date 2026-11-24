
import Foundation
import Supabase

struct WeiChatUser: Codable, Identifiable {
    let id: UUID
    let username: String?
    let nickname: String?
    let wechat_id: String?
}

struct WeiChatMessage: Codable, Identifiable {
    let id: UUID
    let conversation_id: UUID
    let sender_id: UUID
    let content: String
    let message_type: String
    let created_at: Date
}

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }

    // MARK: - 注册

    func signUp(
        email: String,
        password: String,
        nickname: String
    ) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["nickname": .string(nickname)]
        )
    }

    // MARK: - 登录

    func signIn(
        email: String,
        password: String
    ) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    // MARK: - 退出登录

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - 当前用户

    func hasSession() async -> Bool {
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }

    func currentUserID() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

    // MARK: - 搜索用户

    func searchUsers(keyword: String) async throws -> [WeiChatUser] {
        let word = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !word.isEmpty else {
            return []
        }

        return try await client
            .from("profiles")
            .select("id, username, nickname, wechat_id")
            .or("username.ilike.%\(word)%,wechat_id.ilike.%\(word)%")
            .limit(30)
            .execute()
            .value
    }

    // MARK: - 创建私聊

    func createPrivateConversation(
        otherUserID: UUID
    ) async throws -> UUID {
        return try await client
            .rpc(
                "create_private_conversation",
                params: [
                    "p_other_user_id": otherUserID.uuidString
                ]
            )
            .execute()
            .value
    }

    // MARK: - 获取聊天记录

    func fetchMessages(
        conversationID: UUID
    ) async throws -> [WeiChatMessage] {
        return try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - 发送消息

    func sendMessage(
        conversationID: UUID,
        content: String
    ) async throws {
        let text = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty else {
            return
        }

        let userID = try await currentUserID()

        let newMessage = NewWeiChatMessage(
            conversation_id: conversationID,
            sender_id: userID,
            content: text,
            message_type: "text"
        )

        try await client
            .from("messages")
            .insert(newMessage)
            .execute()
    }
}

private struct NewWeiChatMessage: Encodable {
    let conversation_id: UUID
    let sender_id: UUID
    let content: String
    let message_type: String
}
