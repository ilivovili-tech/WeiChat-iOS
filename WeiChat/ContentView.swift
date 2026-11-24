
import SwiftUI

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

                SecureField("密码（至少 6 位）", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 30)

            Button {
                submit()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
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
                        alertMessage = "注册成功！请先到邮箱完成验证，再回来登录。"
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

// MARK: - 聊天列表

struct ChatItem: Identifiable {
    let id = UUID()
    let name: String
    let message: String
    let time: String
    let icon: String
}

let sampleChats = [
    ChatItem(name: "文件传输助手", message: "文件已发送", time: "17:08", icon: "folder.fill"),
    ChatItem(name: "微信团队", message: "欢迎使用微信", time: "16:30", icon: "message.fill"),
    ChatItem(name: "好友一号", message: "你好！", time: "昨天", icon: "person.fill"),
    ChatItem(name: "好友二号", message: "晚上一起吃饭吗？", time: "昨天", icon: "person.fill")
]

struct ChatListView: View {
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(sampleChats.filter {
                    search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                }) { chat in
                    NavigationLink {
                        ChatDetailView(name: chat.name)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: chat.icon)
                                .font(.system(size: 25))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 7) {
                                Text(chat.name)
                                    .font(.system(size: 17, weight: .medium))
                                Text(chat.message)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(chat.time)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("微信")
            .searchable(text: $search, prompt: "搜索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - 聊天详情

struct ChatDetailView: View {
    let name: String
    @State private var message = ""
    @State private var messages = ["你好！", "欢迎使用 WeiChat"]

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages.indices, id: \.self) { index in
                        HStack {
                            Spacer()
                            Text(messages[index])
                                .padding(12)
                                .background(Color.green.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }

            HStack {
                TextField("发送消息...", text: $message)
                    .textFieldStyle(.roundedBorder)

                Button("发送") {
                    guard !message.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    messages.append(message)
                    message = ""
                }
                .foregroundStyle(.green)
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 通讯录

struct ContactsView: View {
    let names = ["新的朋友", "群聊", "标签", "公众号", "好友一号", "好友二号", "好友三号"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(names, id: \.self) { name in
                    HStack(spacing: 15) {
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                        Text(name)
                    }
                    .padding(.vertical, 5)
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

    @State private var nickname = "WeiChat 用户"
    @State private var wechatID = "weichat2026"

    var body: some View {
        NavigationStack {
            List {
                HStack(spacing: 18) {
                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: 65))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(nickname)
                            .font(.title2.bold())
                        Text("微信号：\(wechatID)")
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
