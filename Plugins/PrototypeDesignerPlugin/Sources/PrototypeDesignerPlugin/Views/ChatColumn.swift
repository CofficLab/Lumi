import SwiftUI
import LumiUI

/// 左侧对话区：消息列表 + 输入框。
struct ChatColumn: View {
    @Bindable var viewModel: PrototypeDesignerViewModel

    /// 空态可点击的需求模板，降低冷启动门槛。
    private let templates: [(title: String, prompt: String, systemImage: String)] = [
        ("登录注册页", "设计一个 App 的登录与注册页面：包含手机号/邮箱输入、密码、第三方登录入口，风格简洁现代。", "person.crop.circle.badge.checkmark"),
        ("电商商品列表", "设计一个电商首页：顶部搜索栏、分类入口、商品瀑布流卡片（图、标题、价格、加购按钮）。", "cart.fill"),
        ("数据看板", "设计一个数据看板首页：关键指标卡片、折线图区域、最近订单列表，适合桌面端。", "chart.bar.fill"),
        ("聊天会话列表", "设计一个即时通讯 App 的会话列表页：头像、昵称、最后一条消息、时间、未读红点。", "bubble.left.and.bubble.right.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            conversationList
            inputBar
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - 列表

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.vertical, 24)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        StreamingRow(text: viewModel.streamingText)
                            .id("streaming")
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            if let lastID = viewModel.messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            } else {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("产品原型设计助手", systemImage: "wand.and.stars")
                    .font(.headline)
                Text("用自然语言描述你想要的界面，AI 会生成可交互的高保真原型，并在右侧实时预览。多轮对话即可持续精修。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("试试从这里开始")
                .font(.caption)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(templates, id: \.title) { template in
                    Button {
                        viewModel.applyTemplate(template.prompt)
                    } label: {
                        Label(template.title, systemImage: template.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("描述你想要的界面，或告诉它怎么改…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.inputText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 36, maxHeight: 120)
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if viewModel.isLoading {
                Button {
                    viewModel.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 24, height: 24)
                }
                .help("停止生成")
            } else {
                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canSend)
                .keyboardShortcut(.return, modifiers: .command)
                .help("发送 (⌘↵)")
            }
        }
        .padding(12)
        .background(.bar)
    }
}

// MARK: - 消息行

private struct MessageRow: View {
    let message: PrototypeMessage

    var body: some View {
        let displayText = message.isError ? message.content : strippedText
        HStack {
            if message.role == .user { Spacer(minLength: 32) }
            Text(displayText)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .appMessageBubble(role: bubbleRole, isError: message.isError)
            if message.role == .assistant { Spacer(minLength: 32) }
        }
    }

    private var bubbleRole: MessageBubbleRole {
        switch message.role {
        case .user: .user
        case .assistant: message.isError ? .error : .assistant
        }
    }

    /// 展示时去掉 artifact 标签体，只保留 LLM 的文字说明，避免长 HTML 刷屏。
    private var strippedText: String {
        guard message.role == .assistant else { return message.content }
        let pattern = #"<artifact[^>]*>[\s\S]*?</artifact>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return message.content
        }
        let ns = message.content as NSString
        let trimmed = regex.stringByReplacingMatches(
            in: message.content,
            options: [],
            range: NSRange(location: 0, length: ns.length),
            withTemplate: "〔原型已生成，见右侧预览〕"
        )
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct StreamingRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            if text.isEmpty {
                HStack(spacing: 6) {
                    ThinkingDots()
                    Text("正在思考…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .appMessageBubble(role: .assistant, isError: false)
            } else {
                Text(text)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .appMessageBubble(role: .assistant, isError: false)
            }
            Spacer(minLength: 32)
        }
    }
}

/// 三点呼吸动画，表示正在生成。
private struct ThinkingDots: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .opacity(opacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) {
                phase = 1
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        0.3 + 0.7 * ((sin(phase * .pi * 2 + Double(index) * 0.8) + 1) / 2)
    }
}
