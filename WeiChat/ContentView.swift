
import SwiftUI
import Supabase
import PhotosUI
import UIKit
import MusicKit
import AVFoundation
import UniformTypeIdentifiers
import MediaPlayer
import Combine

// MARK: - 主入口

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var checkingSession = true

    var body: some View {
        Group {
            if checkingSession {
                ProgressView("正在连接 WeiChat...")
            } else if isLoggedIn {
                MainTabView {
                    isLoggedIn = false
                }
            } else {
                LoginView {
                    isLoggedIn = true
                }
            }
        }
        .task {
            isLoggedIn = await SupabaseManager.shared.hasSession()
            checkingSession = false
        }
    }
}

// MARK: - 主界面

struct MainTabView: View {
    var onLogout: () -> Void

    var body: some View {
        TabView {
            ChatListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("微信")
                }

            ContactsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("通讯录")
                }

            DiscoverView()
                .tabItem {
                    Image(systemName: "safari")
                    Text("发现")
                }

            WeiMusicView()
                .tabItem {
                    Image(systemName: "music.note")
                    Text("音乐")
                }

            AIAssistantView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("AI 助手")
                }

            ProfileView(onLogout: onLogout)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我")
                }
        }
        .tint(.green)
    }
}

// MARK: - 登录注册

struct LoginView: View {
    var onLogin: () -> Void

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.green.opacity(0.10),
                    Color(.systemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 65))
                    .foregroundStyle(.green)

                Text("WeiChat")
                    .font(.system(size: 36, weight: .bold))

                Text(isRegistering ? "创建你的 WeiChat 账号" : "欢迎回来")
                    .foregroundStyle(.secondary)

                VStack(spacing: 15) {
                    if isRegistering {
                        TextField("请输入昵称", text: $nickname)
                            .textContentType(.nickname)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("邮箱地址", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(18)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 22)
                )
                .padding(.horizontal, 25)

                Button {
                    submit()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isRegistering ? "注册账号" : "登录")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .disabled(isLoading)
                .padding(.horizontal, 30)

                Button(isRegistering ? "已有账号？立即登录" : "没有账号？立即注册") {
                    isRegistering.toggle()
                }
                .foregroundStyle(.green)

                Spacer()
            }
            .padding()
        }
        .alert("WeiChat 提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func submit() {
        guard email.contains("@") else {
            alertMessage = "请输入正确的邮箱地址。"
            showAlert = true
            return
        }

        guard password.count >= 6 else {
            alertMessage = "密码至少需要 6 位。"
            showAlert = true
            return
        }

        if isRegistering && nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            alertMessage = "请输入昵称。"
            showAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                if isRegistering {
                    try await SupabaseManager.shared.signUp(
                        email: email,
                        password: password,
                        nickname: nickname
                    )

                    if await SupabaseManager.shared.hasSession() {
                        onLogin()
                    } else {
                        alertMessage = "注册成功！请先验证邮箱，再回来登录。"
                        showAlert = true
                    }
                } else {
                    try await SupabaseManager.shared.signIn(
                        email: email,
                        password: password
                    )
                    onLogin()
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }

            isLoading = false
        }
    }
}

// MARK: - AI 助手

struct AIChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct AIAssistantView: View {
    @StateObject private var ai = WeiChatAIManager()
    @State private var messages: [AIChatMessage] = []
    @State private var message = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.green)

                    Text(ai.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Circle()
                        .fill(ai.isAvailable ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollViewReader { proxy in
                    ScrollView {
                        if messages.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 55))
                                    .foregroundStyle(.green)

                                Text("你好，我是 WeiChat AI")
                                    .font(.title2.bold())

                                Text("有什么问题都可以问我。")
                                    .foregroundStyle(.secondary)

                                Text("回答由设备上的 Apple 本地模型生成。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        }

                        LazyVStack(spacing: 16) {
                            ForEach(messages) { item in
                                HStack {
                                    if item.isUser {
                                        Spacer(minLength: 45)

                                        Text(item.text)
                                            .padding(13)
                                            .foregroundStyle(.primary)
                                            .background(
                                                Color.green.opacity(0.20),
                                                in: RoundedRectangle(cornerRadius: 18)
                                            )
                                    } else {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.green)
                                            .padding(.top, 8)

                                        Text(item.text)
                                            .padding(13)
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: .leading
                                            )
                                            .background(
                                                Color.gray.opacity(0.13),
                                                in: RoundedRectangle(cornerRadius: 18)
                                            )

                                        Spacer(minLength: 20)
                                    }
                                }
                                .id(item.id)
                            }

                            if ai.isResponding {
                                HStack {
                                    ProgressView()
                                    Text("AI 正在思考...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.leading, 8)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    TextField(
                        "向 WeiChat AI 提问...",
                        text: $message,
                        axis: .vertical
                    )
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Button {
                        sendMessage()
                    } label: {
                        if ai.isResponding {
                            ProgressView()
                                .frame(width: 42, height: 42)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.green, in: Circle())
                        }
                    }
                    .disabled(
                        ai.isResponding ||
                        message.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
                .padding(7)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 25)
                )
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("WeiChat AI")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                ai.checkAvailability()
            }
        }
    }

    private func sendMessage() {
        let text = message.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty, !ai.isResponding else {
            return
        }

        messages.append(
            AIChatMessage(text: text, isUser: true)
        )

        message = ""

        Task {
            do {
                let answer = try await ai.send(text: text)

                messages.append(
                    AIChatMessage(text: answer, isUser: false)
                )
            } catch {
                messages.append(
                    AIChatMessage(
                        text: "AI 暂时无法回答：\(error.localizedDescription)",
                        isUser: false
                    )
                )
            }
        }
    }
}

// MARK: - 聊天会话

struct ChatSession: Identifiable {
    let id: UUID
    let name: String
}

struct ChatListView: View {
    @State private var search = ""
    @State private var users: [WeiChatUser] = []
    @State private var sessions: [ChatSession] = []
    @State private var isSearching = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField("搜索用户名或微信号", text: $search)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                                .onSubmit {
                                    searchUsers()
                                }

                            Button {
                                searchUsers()
                            } label: {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.green)
                                    .frame(width: 35, height: 35)
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                    }
                    .listRowInsets(
                        EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView("正在搜索...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                if !users.isEmpty {
                    Section("搜索结果") {
                        ForEach(users) { user in
                            Button {
                                openChat(user)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 42))
                                        .foregroundStyle(.green)

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(user.nickname ?? user.username ?? "WeiChat 用户")
                                            .foregroundStyle(.primary)

                                        Text("微信号：\(user.wechat_id ?? user.username ?? "未设置")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isSearching)
                        }
                    }
                }

                Section("最近聊天") {
                    if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 42))
                                .foregroundStyle(.secondary)

                            Text("还没有聊天记录")
                                .foregroundStyle(.secondary)

                            Text("搜索用户，开始新的聊天")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 35)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(sessions) { session in
                            NavigationLink {
                                ChatDetailView(
                                    name: session.name,
                                    conversationID: session.id
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 45))
                                        .foregroundStyle(.green)

                                    Text(session.name)
                                        .font(.system(size: 17))

                                    Spacer()

                                    Text("聊天")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("微信")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        search = ""
                        users = []
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(.green)
                }
            }
            .alert("WeiChat 提示", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func searchUsers() {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !keyword.isEmpty else {
            users = []
            return
        }

        isSearching = true

        Task {
            do {
                let results = try await SupabaseManager.shared.searchUsers(
                    keyword: keyword
                )

                let currentID = try await SupabaseManager.shared.currentUserID()
                users = results.filter { $0.id != currentID }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isSearching = false
        }
    }

    private func openChat(_ user: WeiChatUser) {
        isSearching = true

        Task {
            do {
                let conversationID = try await SupabaseManager.shared
                    .createPrivateConversation(otherUserID: user.id)

                let name = user.nickname ?? user.username ?? "WeiChat 用户"

                if !sessions.contains(where: { $0.id == conversationID }) {
                    sessions.insert(
                        ChatSession(id: conversationID, name: name),
                        at: 0
                    )
                }

                search = ""
                users = []
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isSearching = false
        }
    }
}

// MARK: - 聊天详情

struct ChatDetailView: View {
    let name: String
    let conversationID: UUID

    @State private var messages: [WeiChatMessage] = []
    @State private var currentUserID: UUID?
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(messages) { item in
                            HStack {
                                if item.sender_id == currentUserID {
                                    Spacer(minLength: 55)

                                    Text(item.content)
                                        .padding(12)
                                        .background(Color.green.opacity(0.22))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else {
                                    Text(item.content)
                                        .padding(12)
                                        .background(Color.gray.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))

                                    Spacer(minLength: 55)
                                }
                            }
                            .id(item.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("发送消息...", text: $message, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Button {
                        sendMessage()
                    } label: {
                        if isSending {
                            ProgressView()
                                .frame(width: 42, height: 42)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.green, in: Circle())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        isSending ||
                        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(6)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 24)
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                currentUserID = try await SupabaseManager.shared.currentUserID()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                showError = true
                return
            }

            while !Task.isCancelled {
                await loadMessages()

                guard !Task.isCancelled else { break }

                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch is CancellationError {
                    break
                } catch {
                    break
                }
            }
        }
        .alert("WeiChat 提示", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func loadMessages() async {
        do {
            let result = try await SupabaseManager.shared.fetchMessages(
                conversationID: conversationID
            )

            guard !Task.isCancelled else { return }
            messages = result

        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func sendMessage() {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true

        Task {
            do {
                try await SupabaseManager.shared.sendMessage(
                    conversationID: conversationID,
                    content: text
                )

                message = ""
                await loadMessages()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isSending = false
        }
    }
}

// MARK: - 通讯录

struct ContactsView: View {
    let names = ["新的朋友", "群聊", "标签", "公众号"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: "person.crop.square.fill")
                        .foregroundStyle(.green)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("通讯录")
        }
    }
}

// MARK: - 发现

struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("朋友圈", systemImage: "camera")
                Label("视频号", systemImage: "play.rectangle")
                Label("扫一扫", systemImage: "qrcode.viewfinder")
                Label("摇一摇", systemImage: "iphone.radiowaves.left.and.right")
                Label("看一看", systemImage: "safari")
                Label("搜一搜", systemImage: "magnifyingglass")
                Label("附近的人", systemImage: "location")
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("发现")
        }
    }
}

// MARK: - 我的

struct ProfileView: View {
    var onLogout: () -> Void

    @State private var profile: WeiChatProfile?
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var isLoading = true
    @State private var isUploading = false
    @State private var showEditor = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 18) {
                        avatarView
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 15))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile?.nickname ?? "WeiChat 用户")
                                .font(.title2.bold())

                            Text("微信号：\(profile?.wechat_id ?? "未设置")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(profile?.bio ?? "欢迎使用 WeiChat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showEditor = true
                    }

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        Label(
                            isUploading ? "正在上传头像..." : "更换个人头像",
                            systemImage: "camera"
                        )
                        .foregroundStyle(.green)
                    }
                    .disabled(isUploading)
                }

                Section {
                    Label("服务", systemImage: "creditcard")
                    Label("收藏", systemImage: "star")
                    Label("朋友圈", systemImage: "photo")
                    Label("卡包", systemImage: "wallet.pass")
                    Label("表情", systemImage: "face.smiling")
                }

                Section {
                    Button {
                        showEditor = true
                    } label: {
                        Label("编辑个人资料", systemImage: "person.crop.circle")
                            .foregroundStyle(.primary)
                    }

                    NavigationLink {
                        WeiChatRegionSettingsView()
                    } label: {
                        Label("地区设置", systemImage: "globe.asia.australia")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            do {
                                try await SupabaseManager.shared.signOut()
                                onLogout()
                            } catch {
                                alertMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我")
            .overlay {
                if isLoading {
                    ProgressView("正在加载个人资料...")
                }
            }
            .task {
                await loadProfile()
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }

                Task {
                    await uploadSelectedPhoto(newValue)
                }
            }
            .sheet(isPresented: $showEditor) {
                if let profile {
                    ProfileEditView(profile: profile) {
                        Task {
                            await loadProfile()
                        }
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "暂时无法读取个人资料",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("请检查 profiles 表是否存在当前用户的资料记录。")
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("关闭") {
                                    showEditor = false
                                }
                            }
                        }
                    }
                }
            }
            .alert("WeiChat 提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = profile?.avatar_url,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
        } else {
            Image(systemName: "person.crop.square.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.green)
                .padding(5)
        }
    }

    private func loadProfile() async {
        do {
            let result = try await SupabaseManager.shared.fetchMyProfile()

            guard !Task.isCancelled else { return }
            profile = result

        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            alertMessage = error.localizedDescription
            showAlert = true
        }

        guard !Task.isCancelled else { return }
        isLoading = false
    }

    private func uploadSelectedPhoto(_ item: PhotosPickerItem) async {
        isUploading = true

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(
                    domain: "WeiChat",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "无法读取所选图片"
                    ]
                )
            }

            guard let image = UIImage(data: data),
                  let compressedData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(
                    domain: "WeiChat",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "图片格式无法处理"
                    ]
                )
            }

            _ = try await SupabaseManager.shared.uploadAvatar(
                imageData: compressedData
            )

            await loadProfile()

            alertMessage = "头像上传成功！"
            showAlert = true

        } catch is CancellationError {
            // 正常取消，不显示错误弹窗
        } catch {
            alertMessage = "头像上传失败：\(error.localizedDescription)"
            showAlert = true
        }

        isUploading = false
        selectedPhoto = nil
    }
}

// MARK: - 编辑个人资料

struct ProfileEditView: View {
    let profile: WeiChatProfile
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var wechatID = ""
    @State private var bio = ""

    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基本资料") {
                    TextField("昵称", text: $nickname)
                        .textInputAutocapitalization(.never)

                    TextField("微信号", text: $wechatID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("个人简介")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            "介绍一下自己...",
                            text: $bio,
                            axis: .vertical
                        )
                        .lineLimit(3...5)
                    }
                }

                Section {
                    Text("修改后的资料将保存到 WeiChat 云端数据库。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                nickname = profile.nickname ?? ""
                wechatID = profile.wechat_id ?? ""
                bio = profile.bio ?? ""
            }
            .alert("WeiChat 提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveProfile() {
        let cleanNickname = nickname.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanNickname.isEmpty else {
            alertMessage = "昵称不能为空。"
            showAlert = true
            return
        }

        isSaving = true

        Task {
            do {
                try await SupabaseManager.shared.updateMyProfile(
                    nickname: cleanNickname,
                    wechatID: wechatID.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    bio: bio.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )

                onSaved()
                dismiss()

            } catch {
                alertMessage = "保存失败：\(error.localizedDescription)"
                showAlert = true
            }

            isSaving = false
        }
    }
}


 
 // MARK: - WeiChat 音乐中心

struct WeiMusicView: View {
    @State private var authorizationStatus = MusicAuthorization.currentStatus

    @State private var searchText = ""
    @State private var searchResults: [Song] = []
    @State private var librarySongs: [Song] = []

    @State private var isSearching = false
    @State private var isLoadingLibrary = false

    @State private var localFiles: [URL] = []
    @State private var currentLocalIndex = -1
    @State private var isLocalPlaying = false

    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var volume: Double = 1
    @State private var isSeeking = false

    @State private var isShuffleEnabled = false
    @State private var repeatMode = 0
    // 0 = 列表循环，1 = 单曲循环，2 = 顺序播放

    @State private var showImporter = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    @StateObject private var localPlayer = LocalMusicPlayer.shared

    private let musicPlayer = ApplicationMusicPlayer.shared

    private let progressTimer = Timer.publish(
        every: 0.5,
        on: .main,
        in: .common
    ).autoconnect()

    private var currentLocalURL: URL? {
        guard localFiles.indices.contains(currentLocalIndex) else {
            return nil
        }
        return localFiles[currentLocalIndex]
    }

    private var currentLocalSong: String {
        guard let url = currentLocalURL else {
            return ""
        }

        return url.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Apple Music

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 30))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Apple Music")
                                .font(.headline)

                            Text(authorizationText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if authorizationStatus == .authorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("授权") {
                                requestAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // MARK: 在线音乐

                Section("在线音乐") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("搜索歌曲或歌手", text: $searchText)
                            .submitLabel(.search)
                            .onSubmit {
                                searchMusic()
                            }

                        Button {
                            searchMusic()
                        } label: {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.green)
                        }
                        .disabled(
                            searchText.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty || isSearching
                        )
                    }

                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView("正在搜索音乐...")
                            Spacer()
                        }
                    }

                    ForEach(searchResults, id: \.id) { song in
                        songRow(song)
                    }

                    if searchResults.isEmpty && !isSearching {
                        Text("搜索你喜欢的歌曲和歌手")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Apple Music 资料库

                Section {
                    HStack {
                        Text("我的音乐资料库")
                            .font(.headline)

                        Spacer()

                        Button("刷新") {
                            loadLibrary()
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                        .disabled(isLoadingLibrary)
                    }

                    if isLoadingLibrary {
                        ProgressView("正在读取音乐资料库...")
                    } else if librarySongs.isEmpty {
                        Text("授权后可以读取你的音乐资料库")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(librarySongs, id: \.id) { song in
                            songRow(song)
                        }
                    }
                }

                // MARK: 本地音乐

                Section("iPhone 本地音乐") {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("本地音频文件")
                                .font(.headline)

                            Text("已导入 \(localFiles.count) 首")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            showImporter = true
                        } label: {
                            Label("导入音乐", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    if localFiles.isEmpty {
                        ContentUnavailableView(
                            "还没有本地音乐",
                            systemImage: "music.note",
                            description: Text("从文件 App 导入 MP3、M4A、AAC、WAV 等音频。")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(localFiles.enumerated()), id: \.element) { index, url in
                            Button {
                                playLocalFile(at: index)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.green.opacity(0.12))
                                            .frame(width: 48, height: 48)

                                        Image(
                                            systemName: currentLocalIndex == index && isLocalPlaying
                                                ? "waveform"
                                                : "music.note"
                                        )
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(
                                            url.deletingPathExtension()
                                                .lastPathComponent
                                        )
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                        Text(url.pathExtension.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if currentLocalIndex == index {
                                        Image(
                                            systemName: isLocalPlaying
                                                ? "speaker.wave.2.fill"
                                                : "pause.circle"
                                        )
                                        .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "play.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteLocalFile(at: index)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // MARK: 播放器

                if currentLocalURL != nil {
                    Section("正在播放") {
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .green.opacity(0.3),
                                                .blue.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 155)

                                VStack(spacing: 10) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 55))
                                        .foregroundStyle(.green)

                                    Text("WeiMusic")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(spacing: 5) {
                                Text(currentLocalSong)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(isLocalPlaying ? "正在播放" : "已暂停")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // 进度条

                            VStack(spacing: 5) {
                                Slider(
                                    value: Binding(
                                        get: {
                                            min(currentTime, max(duration, 0))
                                        },
                                        set: { newValue in
                                            isSeeking = true
                                            currentTime = newValue
                                        }
                                    ),
                                    in: 0...max(duration, 1),
                                    onEditingChanged: { editing in
                                        if !editing {
                                            localPlayer.seek(to: currentTime)
                                            isSeeking = false
                                        }
                                    }
                                )
                                .tint(.green)

                                HStack {
                                    Text(formatTime(currentTime))

                                    Spacer()

                                    Text(formatTime(duration))
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }

                            // 播放控制

                            HStack {
                                Button {
                                    isShuffleEnabled.toggle()
                                } label: {
                                    Image(systemName: "shuffle")
                                        .foregroundStyle(
                                            isShuffleEnabled ? .green : .secondary
                                        )
                                }

                                Spacer()

                                Button {
                                    playPrevious()
                                } label: {
                                    Image(systemName: "backward.end.fill")
                                        .font(.title2)
                                }

                                Spacer()

                                Button {
                                    toggleLocalPlayback()
                                } label: {
                                    Image(
                                        systemName: isLocalPlaying
                                            ? "pause.circle.fill"
                                            : "play.circle.fill"
                                    )
                                    .font(.system(size: 52))
                                }

                                Spacer()

                                Button {
                                    playNext()
                                } label: {
                                    Image(systemName: "forward.end.fill")
                                        .font(.title2)
                                }

                                Spacer()

                                Button {
                                    repeatMode = (repeatMode + 1) % 3
                                } label: {
                                    Image(
                                        systemName: repeatMode == 1
                                            ? "repeat.1"
                                            : "repeat"
                                    )
                                    .foregroundStyle(
                                        repeatMode == 0 ? .secondary : .green
                                    )
                                }
                            }
                            .foregroundStyle(.green)
                            .padding(.vertical, 8)

                            // 音量控制

                            HStack(spacing: 10) {
                                Image(systemName: "speaker.fill")
                                    .foregroundStyle(.secondary)

                                Slider(value: $volume, in: 0...1)
                                    .tint(.green)
                                    .onChange(of: volume) { _, newValue in
                                        localPlayer.setVolume(Float(newValue))
                                    }

                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("音乐")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .tint(.green)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                importAudioFiles(result)
            }
            .onReceive(progressTimer) { _ in
                guard !isSeeking else { return }

                currentTime = localPlayer.currentTime
                duration = localPlayer.duration
                isLocalPlaying = localPlayer.isPlaying
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .AVPlayerItemDidPlayToEndTime
                )
            ) { notification in
                guard
                    let finishedItem = notification.object as? AVPlayerItem,
                    finishedItem === localPlayer.player?.currentItem
                else {
                    return
                }

                handlePlaybackFinished()
            }
            .alert("WeiChat 音乐", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .task {
                authorizationStatus = MusicAuthorization.currentStatus
                loadLocalFiles()

                localPlayer.configure()

                if authorizationStatus == .authorized {
                    loadLibrary()
                }
            }
        }
    }

    // MARK: 授权状态

    private var authorizationText: String {
        switch authorizationStatus {
        case .authorized:
            return "已获得音乐访问权限"
        case .denied:
            return "访问权限已被拒绝，请在系统设置中检查"
        case .restricted:
            return "当前设备限制了音乐访问"
        case .notDetermined:
            return "需要授权才能搜索和读取 Apple Music"
        @unknown default:
            return "音乐授权状态未知"
        }
    }

    private func requestAuthorization() {
        Task {
            let status = await MusicAuthorization.request()

            authorizationStatus = status

            if status == .authorized {
                loadLibrary()
            } else {
                alertMessage = "没有获得 Apple Music 授权。"
                showAlert = true
            }
        }
    }

    // MARK: 在线搜索

    private func searchMusic() {
        let keyword = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !keyword.isEmpty else { return }

        guard authorizationStatus == .authorized else {
            alertMessage = "请先授权 Apple Music。"
            showAlert = true
            return
        }

        isSearching = true
        searchResults = []

        Task {
            do {
                var request = MusicCatalogSearchRequest(
                    term: keyword,
                    types: [Song.self]
                )

                request.limit = 25

                let response = try await request.response()

                searchResults = Array(response.songs)

            } catch {
                alertMessage = "搜索失败：\(error.localizedDescription)"
                showAlert = true
            }

            isSearching = false
        }
    }

    // MARK: Apple Music 资料库

    private func loadLibrary() {
        guard authorizationStatus == .authorized else { return }

        isLoadingLibrary = true

        Task {
            do {
                let request = MusicLibraryRequest<Song>()
                let response = try await request.response()

                librarySongs = Array(response.items.prefix(100))

            } catch {
                alertMessage = "读取音乐资料库失败：\(error.localizedDescription)"
                showAlert = true
            }

            isLoadingLibrary = false
        }
    }

    // MARK: Apple Music 播放

    private func playSong(_ song: Song) {
        guard authorizationStatus == .authorized else {
            alertMessage = "请先授权 Apple Music。"
            showAlert = true
            return
        }

        localPlayer.stop()

        isLocalPlaying = false
        currentLocalIndex = -1
        currentTime = 0
        duration = 0

        Task {
            do {
                musicPlayer.queue = [song]
                try await musicPlayer.play()
            } catch {
                alertMessage = "Apple Music 播放失败：\(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    @ViewBuilder
    private func songRow(_ song: Song) -> some View {
        Button {
            playSong(song)
        } label: {
            HStack(spacing: 12) {
                if let artwork = song.artwork {
                    ArtworkImage(artwork, width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 48, height: 48)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: 导入音频文件

    private func importAudioFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):

            guard !urls.isEmpty else { return }

            let fileManager = FileManager.default

            guard let documents = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
                alertMessage = "无法访问应用文件目录。"
                showAlert = true
                return
            }

            let musicFolder = documents.appendingPathComponent(
                "WeiMusic",
                isDirectory: true
            )

            do {
                try fileManager.createDirectory(
                    at: musicFolder,
                    withIntermediateDirectories: true
                )

                var importedCount = 0
                var failures: [String] = []

                for sourceURL in urls {
                    do {
                        try copyAudioFile(
                            from: sourceURL,
                            to: musicFolder,
                            fileManager: fileManager
                        )

                        importedCount += 1

                    } catch {
                        failures.append(
                            "\(sourceURL.lastPathComponent)：\(error.localizedDescription)"
                        )
                    }
                }

                loadLocalFiles()

                if failures.isEmpty {
                    alertMessage = "成功导入 \(importedCount) 首音乐！"
                } else {
                    let details = failures.prefix(3).joined(separator: "\n")

                    alertMessage = """
                    成功导入：\(importedCount) 首
                    导入失败：\(failures.count) 首

                    \(details)
                    """
                }

                showAlert = true

            } catch {
                alertMessage = "创建音乐目录失败：\(error.localizedDescription)"
                showAlert = true
            }

        case .failure(let error):
            alertMessage = "选择文件失败：\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: 安全复制文件

    private func copyAudioFile(
        from source: URL,
        to folder: URL,
        fileManager: FileManager
    ) throws {

        let accessGranted = source.startAccessingSecurityScopedResource()

        defer {
            if accessGranted {
                source.stopAccessingSecurityScopedResource()
            }
        }

        var coordinationError: NSError?
        var copyError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(
            readingItemAt: source,
            options: [],
            error: &coordinationError
        ) { readableURL in

            do {
                let ext = readableURL.pathExtension.lowercased()

                let supported = [
                    "mp3", "m4a", "aac", "wav",
                    "aiff", "aif", "caf", "flac"
                ]

                guard supported.contains(ext) else {
                    throw NSError(
                        domain: "WeiChatMusic",
                        code: 1001,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "不支持的音频格式：\(ext)"
                        ]
                    )
                }

                let originalName = readableURL.lastPathComponent

                var destination = folder.appendingPathComponent(originalName)

                if fileManager.fileExists(atPath: destination.path) {
                    let name = readableURL.deletingPathExtension()
                        .lastPathComponent

                    let newName = "\(name)_\(UUID().uuidString.prefix(8)).\(ext)"

                    destination = folder.appendingPathComponent(newName)
                }

                try fileManager.copyItem(
                    at: readableURL,
                    to: destination
                )

            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        if let copyError {
            throw copyError
        }
    }

    // MARK: 读取本地音乐

    private func loadLocalFiles() {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        let folder = documents.appendingPathComponent(
            "WeiMusic",
            isDirectory: true
        )

        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [
                    .isRegularFileKey
                ]
            )

            let supported = [
                "mp3", "m4a", "aac", "wav",
                "aiff", "aif", "caf", "flac"
            ]

            localFiles = files
                .filter {
                    supported.contains($0.pathExtension.lowercased())
                }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare(
                        $1.lastPathComponent
                    ) == .orderedAscending
                }

        } catch {
            alertMessage = "读取本地音乐失败：\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: 播放本地音乐

    private func playLocalFile(at index: Int) {
        guard localFiles.indices.contains(index) else { return }

        let url = localFiles[index]

        do {
            try localPlayer.play(url: url)

            currentLocalIndex = index
            isLocalPlaying = true

            currentTime = 0
            duration = localPlayer.duration

        } catch {
            alertMessage = "无法播放该文件：\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: 播放暂停

    private func toggleLocalPlayback() {
        guard currentLocalURL != nil else { return }

        localPlayer.togglePlayback()
        isLocalPlaying = localPlayer.isPlaying
    }

    // MARK: 上一首

    private func playPrevious() {
        guard !localFiles.isEmpty else { return }

        if currentTime > 3 {
            localPlayer.seek(to: 0)
            currentTime = 0
            return
        }

        let index = currentLocalIndex <= 0
            ? localFiles.count - 1
            : currentLocalIndex - 1

        playLocalFile(at: index)
    }

    // MARK: 下一首

    private func playNext() {
        guard !localFiles.isEmpty else { return }

        let nextIndex: Int

        if isShuffleEnabled && localFiles.count > 1 {
            var randomIndex = currentLocalIndex

            while randomIndex == currentLocalIndex {
                randomIndex = Int.random(in: 0..<localFiles.count)
            }

            nextIndex = randomIndex

        } else if currentLocalIndex >= localFiles.count - 1 {
            if repeatMode == 0 {
                nextIndex = 0
            } else {
                localPlayer.stop()
                isLocalPlaying = false
                return
            }
        } else {
            nextIndex = max(currentLocalIndex + 1, 0)
        }

        playLocalFile(at: nextIndex)
    }

    // MARK: 播放完成

    private func handlePlaybackFinished() {
        if repeatMode == 1 {
            localPlayer.seek(to: 0)
            localPlayer.play()
            isLocalPlaying = true
        } else {
            playNext()
        }
    }

    // MARK: 删除歌曲

    private func deleteLocalFile(at index: Int) {
        guard localFiles.indices.contains(index) else { return }

        let url = localFiles[index]

        do {
            if currentLocalIndex == index {
                localPlayer.stop()
                currentLocalIndex = -1
                isLocalPlaying = false
                currentTime = 0
                duration = 0

            } else if index < currentLocalIndex {
                currentLocalIndex -= 1
            }

            try FileManager.default.removeItem(at: url)

            loadLocalFiles()

            alertMessage = "歌曲已删除。"
            showAlert = true

        } catch {
            alertMessage = "删除失败：\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: 时间格式

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00:00"
        }

        let total = Int(seconds)
        let minutes = total / 60
        let remainingSeconds = total % 60

        return String(
            format: "%02d:%02d",
            minutes,
            remainingSeconds
        )
    }
}


// MARK: - 本地音乐播放器

final class LocalMusicPlayer: ObservableObject {

    static let shared = LocalMusicPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    var player: AVPlayer?

    private var remoteCommandsConfigured = false

    private init() {}

    // MARK: 初始化音频

    func configure() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )

            try AVAudioSession.sharedInstance().setActive(true)

            configureRemoteCommands()

        } catch {
            print("WeiMusic 音频初始化失败：\(error.localizedDescription)")
        }
    }

    // MARK: 播放文件

    func play(url: URL) throws {
        configure()

        let asset = AVURLAsset(url: url)

        let item = AVPlayerItem(asset: asset)

        let newPlayer = AVPlayer(playerItem: item)

        newPlayer.volume = player?.volume ?? 1

        player?.pause()

        player = newPlayer

        newPlayer.play()

        isPlaying = true

        currentTime = 0
        duration = 0

        updateNowPlayingInfo(
            title: url.deletingPathExtension().lastPathComponent
        )

        Task {
            do {
                let loadedDuration = try await asset.load(.duration)

                let seconds = CMTimeGetSeconds(loadedDuration)

                if seconds.isFinite {
                    await MainActor.run {
                        self.duration = seconds
                    }
                }
            } catch {
                print("无法读取歌曲时长：\(error.localizedDescription)")
            }
        }
    }

    // MARK: 暂停继续

    func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    // MARK: 停止

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil

        isPlaying = false
        currentTime = 0
        duration = 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: 进度跳转

    func seek(to seconds: Double) {
        guard let player else { return }

        let safeSeconds = max(0, min(seconds, duration))

        let time = CMTime(
            seconds: safeSeconds,
            preferredTimescale: 600
        )

        player.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )

        currentTime = safeSeconds
    }

    // MARK: 音量

    func setVolume(_ value: Float) {
        player?.volume = max(0, min(value, 1))
    }

    // MARK: 更新播放进度

    func updateProgress() {
        guard let player else { return }

        let time = CMTimeGetSeconds(player.currentTime())

        if time.isFinite {
            currentTime = time
        }

        if let item = player.currentItem {
            let total = CMTimeGetSeconds(item.duration)

            if total.isFinite {
                duration = total
            }
        }

        isPlaying = player.timeControlStatus == .playing
    }

    // MARK: 锁屏信息

    private func updateNowPlayingInfo(title: String) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "WeiChat 本地音乐",
            MPMediaItemPropertyAlbumTitle: "WeiMusic",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0
        ]

        info[MPMediaItemPropertyPlaybackDuration] = duration

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: 耳机和锁屏控制

    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }

        remoteCommandsConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayback()
            return .success
        }

        center.changePlaybackPositionCommand.addTarget {
            [weak self] event in

            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            self?.seek(to: positionEvent.positionTime)

            return .success
        }

        // 下一首和上一首由界面播放器负责切换。
        // 没有注册虚假的切歌处理器。
    }
}
