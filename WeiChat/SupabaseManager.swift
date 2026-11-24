
import Foundation
import Supabase

// MARK: - 用户模型

struct WeiChatUser: Codable, Identifiable {
    let id: UUID
    let username: String?
    let nickname: String?
    let wechat_id: String?
}

// MARK: - 个人资料模型

struct WeiChatProfile: Codable, Identifiable {
    let id: UUID
    var username: String?
    var nickname: String?
    var avatar_url: String?
    var wechat_id: String?
    var bio: String?
}

// MARK: - 聊天消息模型

struct WeiChatMessage: Codable, Identifiable {
    let id: UUID
    let conversation_id: UUID
    let sender_id: UUID
    let content: String
    let message_type: String
    let created_at: Date
}

// MARK: - Supabase 管理器

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

    // MARK: - 获取个人资料

    func fetchMyProfile() async throws -> WeiChatProfile? {
        let userID = try await currentUserID()

        let profiles: [WeiChatProfile] = try await client
            .from("profiles")
            .select("id, username, nickname, avatar_url, wechat_id, bio")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        return profiles.first
    }

    // MARK: - 修改个人资料

    func updateMyProfile(
        nickname: String,
        wechatID: String,
        bio: String
    ) async throws {
        let userID = try await currentUserID()

        let update = ProfileUpdate(
            nickname: nickname,
            wechat_id: wechatID.isEmpty ? nil : wechatID,
            bio: bio,
            updated_at: Date()
        )

        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userID.uuidString)
            .execute()
    }

    // MARK: - 上传头像

    func uploadAvatar(imageData: Data) async throws -> String {
        let userID = try await currentUserID()

        let fileName = UUID().uuidString + ".jpg"
        let path = "\(userID.uuidString)/\(fileName)"

        try await client.storage
            .from("avatars")
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: path)

        let update = AvatarUpdate(
            avatar_url: publicURL.absoluteString,
            updated_at: Date()
        )

        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userID.uuidString)
            .execute()

        return publicURL.absoluteString
    }

    // MARK: - 搜索用户

    func searchUsers(keyword: String) async throws -> [WeiChatUser] {
        let word = keyword.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

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
            .eq(
                "conversation_id",
                value: conversationID.uuidString
            )
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

// MARK: - 数据更新模型

private struct ProfileUpdate: Encodable {
    let nickname: String
    let wechat_id: String?
    let bio: String
    let updated_at: Date
}

private struct AvatarUpdate: Encodable {
    let avatar_url: String
    let updated_at: Date
}

private struct NewWeiChatMessage: Encodable {
    let conversation_id: UUID
    let sender_id: UUID
    let content: String
    let message_type: String
}
