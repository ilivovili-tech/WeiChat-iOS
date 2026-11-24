
import SwiftUI
import Supabase

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
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 65))
                .foregroundStyle(.green)

            Text("WeiChat")
                .font(.system(size: 34, weight: .bold))

            Text(isRegistering ? "创建你的 WeiChat 账号" : "欢迎回来")
                .foregroundStyle(.secondary)

            VStack(spacing: 15) {
                if isRegistering {
                    TextField("请输入昵称", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("邮箱地址", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 30)

            Button {
                submit()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isRegistering ? "注册账号" : "登录")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)
            .padding(.horizontal, 30)

            Button(isRegistering ? "已有账号？立即登录" : "没有账号？立即注册") {
                isRegistering.toggle()
            }
            .foregroundStyle(.green)

            Spacer()
        }
        .padding()
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

            ProfileView(onLogout: onLogout)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我")
                }
        }
        .tint(.green)
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
                    HStack {
                        TextField("搜索用户名或微信号", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            searchUsers()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.green)
                        }
                    }
                }

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView("正在搜索...")
                        Spacer()
                    }
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
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(isSearching)
                        }
                    }
                }

                Section("最近聊天") {
                    if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 38))
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
            .listStyle(.plain)
            .navigationTitle("微信")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.green)
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
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Text(item.content)
                                        .padding(12)
                                        .background(Color.gray.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))

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

            Divider()

            HStack(spacing: 10) {
                TextField("发送消息...", text: $message, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    sendMessage()
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("发送")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.green)
                .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                currentUserID = try await SupabaseManager.shared.currentUserID()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            while !Task.isCancelled {
                await loadMessages()

                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
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
            messages = result
        } catch {
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
            .navigationTitle("发现")
        }
    }
}

// MARK: - 我的

struct ProfileView: View {
    var onLogout: () -> Void

    var body: some View {
        NavigationStack {
            List {
                HStack(spacing: 18) {
                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: 65))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("WeiChat 用户")
                            .font(.title2.bold())

                        Text("欢迎使用 WeiChat")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 15)

                Label("服务", systemImage: "creditcard")
                Label("收藏", systemImage: "star")
                Label("朋友圈", systemImage: "photo")
                Label("卡包", systemImage: "wallet.pass")
                Label("表情", systemImage: "face.smiling")
                Label("设置", systemImage: "gearshape")

                Button(role: .destructive) {
                    Task {
                        do {
                            try await SupabaseManager.shared.signOut()
                            onLogout()
                        } catch {
                            print("退出登录失败：\(error)")
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
            .navigationTitle("我")
        }
    }
}
