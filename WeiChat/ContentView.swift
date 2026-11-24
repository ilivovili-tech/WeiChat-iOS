
import SwiftUI

struct ContentView: View {
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

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我")
                }
        }
        .tint(.green)
    }
}

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

struct ProfileView: View {
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
            }
            .navigationTitle("我")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("编辑") {
                        nickname = nickname == "WeiChat 用户" ? "我的昵称" : "WeiChat 用户"
                    }
                }
            }
        }
    }
}
