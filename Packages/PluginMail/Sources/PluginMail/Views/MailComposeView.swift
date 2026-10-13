import SwiftUI
import UniformTypeIdentifiers
import LumiUI
import KitMail

/// 撰写视图：新写/回复/转发三模式。
///
/// 支持附件拖入、发送中/失败/成功状态条、本地草稿自动保存提示。
struct MailComposeView: View {
    @LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel: MailComposeViewModel
    private let onClose: () -> Void

    @State private var isDropTargeted = false

    public init(
        viewModel: MailComposeViewModel,
        onClose: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            attachmentSection
            footer
        }
        .frame(minWidth: 520, idealWidth: 640, minHeight: 480)
        .onDrop(
            of: [.data, .fileURL],
            isTargeted: $isDropTargeted
        ) { providers in
            handleDrop(providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDropTargeted ? theme.primary : .clear, lineWidth: 2)
        )
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .sent {
                onClose()
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)
            Spacer()
            if let savedAt = viewModel.draftSavedAt {
                Text("草稿已保存 \(savedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }
            AppButton("关闭", style: .secondary, size: .small) {
                onClose()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var title: String {
        switch viewModel.mode {
        case .new: return "写邮件"
        case .reply: return "回复"
        case .forward: return "转发"
        }
    }

    // MARK: - 表单

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                fieldRow("收件人", text: $viewModel.to, placeholder: "name@example.com, name2@example.com")
                fieldRow("抄送", text: $viewModel.cc, placeholder: "（可选）")
                fieldRow("主题", text: $viewModel.subject, placeholder: "（可选）")
                Divider()
                TextEditor(text: $viewModel.body)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.appListRowBackground)
                    )
                    .onChange(of: viewModel.body) { _, _ in
                        viewModel.saveDraftNow()
                    }
            }
            .padding(16)
        }
    }

    private func fieldRow(
        _ label: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
                .frame(width: 56, alignment: .trailing)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
        }
    }

    // MARK: - 附件

    private var attachmentSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperclip")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
            if viewModel.attachments.isEmpty {
                Text("拖入附件到窗口，或点击添加")
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            } else {
                ForEach(Array(viewModel.attachments.enumerated()), id: \.offset) { index, attachment in
                    HStack(spacing: 4) {
                        Text(attachment.filename)
                            .font(.appCaption)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        Button {
                            viewModel.removeAttachment(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.appCaption)
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.appListRowBackground))
                }
            }
            Spacer()
            if !viewModel.attachments.isEmpty {
                Text("\(viewModel.attachments.count) 个附件")
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 8) {
            if case .failed(let message) = viewModel.phase {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                    Text(message)
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                    Spacer()
                }
            }
            HStack(spacing: 8) {
                Spacer()
                AppButton("取消", style: .secondary, fillsWidth: true) {
                    onClose()
                }
                AppButton(
                    viewModel.phase == .sending ? "发送中…" : "发送",
                    style: .primary,
                    fillsWidth: true
                ) {
                    viewModel.send()
                }
                .disabled(viewModel.phase == .sending)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 拖放

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL,
                       let data = try? Data(contentsOf: url) {
                        Task { @MainActor in
                            viewModel.addAttachment(data, filename: url.lastPathComponent)
                        }
                    }
                }
                accepted = true
            }
        }
        return accepted
    }
}
