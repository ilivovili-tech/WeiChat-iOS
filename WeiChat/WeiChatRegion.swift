
import SwiftUI
import Foundation

struct WeiChatRegionOption: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String
    let language: String
    let timeZone: String

    var id: String { code }

    static let all: [WeiChatRegionOption] = [
        .init(code: "KR", name: "韩国", flag: "🇰🇷",
              language: "ko_KR", timeZone: "Asia/Seoul"),
        .init(code: "JP", name: "日本", flag: "🇯🇵",
              language: "ja_JP", timeZone: "Asia/Tokyo"),
        .init(code: "CN", name: "中国大陆", flag: "🇨🇳",
              language: "zh_CN", timeZone: "Asia/Shanghai"),
        .init(code: "HK", name: "中国香港", flag: "🇭🇰",
              language: "zh_HK", timeZone: "Asia/Hong_Kong"),
        .init(code: "US", name: "美国", flag: "🇺🇸",
              language: "en_US", timeZone: "America/Los_Angeles"),
        .init(code: "GB", name: "英国", flag: "🇬🇧",
              language: "en_GB", timeZone: "Europe/London")
    ]
}

enum WeiChatRegion {
    static let storageKey = "wechat_region_code"

    static var current: WeiChatRegionOption {
        let code = UserDefaults.standard.string(
            forKey: storageKey
        ) ?? "KR"

        return WeiChatRegionOption.all.first {
            $0.code == code
        } ?? WeiChatRegionOption.all[0]
    }
}

struct WeiChatRegionSettingsView: View {

    @AppStorage(WeiChatRegion.storageKey)
    private var selectedCode = "KR"

    var body: some View {
        List {
            Section {
                ForEach(WeiChatRegionOption.all) { region in
                    Button {
                        selectedCode = region.code
                    } label: {
                        HStack(spacing: 14) {
                            Text(region.flag)
                                .font(.largeTitle)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(region.name)
                                    .foregroundStyle(.primary)

                                Text(region.code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedCode == region.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("选择你的地区")
            }

            Section {
                HStack {
                    Text("当前地区")
                    Spacer()
                    Text(WeiChatRegionOption.all.first {
                        $0.code == selectedCode
                    }?.name ?? "韩国")
                    .foregroundStyle(.secondary)
                }
            } footer: {
                Text("地区选择保存在本机。修改地区不会改变 Apple Intelligence 的设备资格或系统账户地区。")
            }
        }
        .navigationTitle("地区设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
