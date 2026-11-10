import Foundation
import SwiftUI

extension String {
    /// 根据字符串内容生成相关的 emoji 并添加到原始内容前
    /// - Returns: emoji + 原始内容的组合字符串
    var withContextEmoji: String {
        let emoji = self.generateContextEmoji()
        return "\(emoji) \(self)"
    }

    /// 根据字符串内容分析并生成相关的 emoji
    /// - Returns: 相关的 emoji
    func generateContextEmoji() -> String {
        let lowercased = self.lowercased()
        
        // 定义一个包含所有匹配的元组，按优先级排序
        let emojiMappings: [(String, String)] = [
            ("archive", "💼"), ("归档", "💼"),
            ("appear", "👀"), ("出现", "👀"),
            ("backup", "💼"), ("备份", "💼"),
            ("bypass", "⏭️"), ("绕过", "⏭️"),
            ("click", "👆"), ("点击", "👆"),
            ("complete", "✅"), ("完成", "✅"),
            ("config", "🚩"), ("配置", "🚩"),
            ("crash", "❌"), ("崩溃", "❌"),
            ("data", "💾"), ("数据", "💾"),
            ("debug", "🔍"), ("调试", "🔍"),
            ("display", "👀"), ("展示", "👀"),
            ("done", "✅"), ("完成", "✅"),
            ("error", "❌"), ("错误", "❌"),
            ("fail", "❌"), ("失败", "❌"),
            ("finish", "✅"), ("结束", "✅"),
            ("http", "🌐"), ("HTTP", "🌐"),
            ("ignore", "⏭️"), ("忽略", "⏭️"),
            ("init", "🚩"), ("初始化", "🚩"),
            ("load", "💾"), ("加载", "💾"),
            ("manager", "👔"), ("经理", "👔"),
            ("merge", "🔗"), ("合并", "🔗"),
            ("memory", "📊"), ("内存", "📊"),
            ("modify", "🍋"), ("修改", "🍋"),
            ("network", "🌐"), ("网络", "🌐"),
            ("notification", "🔔"), ("通知", "🔔"),
            ("ok", "✅"), ("好的", "✅"),
            ("performance", "📊"), ("性能", "📊"),
            ("plugin", "🔌"), ("插件", "🔌"),
            ("push", "⬆️"), ("推送", "⬆️"),
            ("ready", "✅"), ("准备好", "✅"),
            ("save", "💾"), ("保存", "💾"),
            ("set", "⚙️"), ("设置", "⚙️"),
            ("show", "👀"), ("显示", "👀"),
            ("skip", "⏭️"), ("跳过", "⏭️"),
            ("synchronize", "🔄"), ("同步", "🔄"),
            ("tap", "👆"), ("轻触", "👆"),
            ("test", "🔍"), ("测试", "🔍"),
            ("update", "🍋"), ("更新", "🍋"),
            ("uuid", "🆔"), ("唯一标识符", "🆔"),
            ("visible", "👀"), ("可见", "👀"),
            ("warn", "⚠️"), ("警告", "⚠️"),
            ("warning", "⚠️"), ("警告", "⚠️"),
        ]

        // 遍历所有映射，优先返回匹配的 emoji
        for (keyword, emoji) in emojiMappings {
            if lowercased.hasPrefix(keyword) || lowercased.contains(keyword) {
                return emoji
            }
        }

        // 默认返回一个通用的 emoji
        return "📝"
    }
}   

    struct StringEmojiPreview: View {
        let examples = [
            // 错误和警告
            "网络请求失败了",
            "警告：内存使用过高",

            // 成功和完成
            "数据保存成功",
            "任务完成",

            // 网络相关
            "发起网络请求",
            "HTTP响应超时",

            // 数据相关
            "正在加载数据",
            "开始保存文件",

            // 初始化和配置
            "初始化系统配置",
            "设置用户参数",

            // 更新和变化
            "更新用户信息",
            "修改配置文件",

            // 调试和测试
            "调试模式启动",
            "开始性能测试",

            // 性能相关
            "CPU使用率过高",
            "检测内存泄漏",

            // 用户交互
            "用户点击登录按钮",
            "检测到双指手势",

            // 跳过相关
            "跳过此步骤",
            "忽略错误继续",
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.self) { text in
                    Text("原始文本：\(text)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("添加 Emoji：\(text.withContextEmoji)")
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // #Preview {
    //     StringEmojiPreview()
    // }
