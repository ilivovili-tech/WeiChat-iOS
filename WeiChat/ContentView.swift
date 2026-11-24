
import SwiftUI
import Supabase
import PhotosUI
import UIKit

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

// MARK: - AI 助手

struct AIAssistantView: View {
    @State private var message = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isLoadingImage = false
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {

                        VStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)

                            Text("WeiChat AI 助手")
                                .font(.title2.bold())

                            Text("智能聊天、图片理解与创作")
                                .foregroundStyle(.secondary)

                            Text("AI 服务尚未连接")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Color.orange.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 35)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 24)
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            Text("未来可以使用的功能")
                                .font(.headline)

                            featureRow(
                                "智能聊天",
                                detail: "回答问题、交流想法、连续对话",
                                icon: "bubble.left.and.bubble.right"
                            )

                            featureRow(
                                "图片理解",
                                detail: "发送照片，让 AI 分析图片内容",
                                icon: "photo"
                            )

                            featureRow(
                                "图片创作",
                                detail: "根据文字描述生成图片",
                                icon: "paintbrush"
                            )

                            featureRow(
                                "文件分析",
                                detail: "阅读、总结和整理文件",
                                icon: "doc.text"
                            )
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 22)
                        )

                        if let data = selectedImageData,
                           let image = UIImage(data: data) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("已选择图片（仅本地预览）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 16)
                                    )

                                Button("移除图片") {
                                    selectedImageData = nil
                                    selectedPhoto = nil
                                }
                                .foregroundStyle(.red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                        }
                    }
                    .padding()
                }

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 25))
                                .foregroundStyle(.green)
                        }
                        .disabled(isLoadingImage)

                        TextField(
                            "向 AI 助手提问...",
                            text: $message,
                            axis: .vertical
                        )
                        .lineLimit(1...4)

                        Button {
                            showAlert = true
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.green, in: Circle())
                        }
                        .disabled(
                            message.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty && selectedImageData == nil
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(
                        .regular,
                        in: RoundedRectangle(cornerRadius: 25)
                    )

                    Text("目前仅支持本地界面预览，AI 服务接入后才能发送并获得回答。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI 助手")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }

                Task {
                    isLoadingImage = true
                    selectedImageData = try? await newValue.loadTransferable(
                        type: Data.self
                    )
                    isLoadingImage = false
                }
            }
            .alert("AI 服务尚未接入", isPresented: $showAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("你的文字和图片目前不会发送到 AI，也不会产生模拟回答。等接入真正的 AI 服务后，就可以开始聊天和图片分析。")
            }
        }
    }

    private func featureRow(
        _ title: String,
        detail: String,
        icon: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.green)
                .frame(width: 35)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                    Label("设置", systemImage: "gearshape")
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

    // MARK: 读取资料（处理任务取消）

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

    // MARK: 上传头像

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
