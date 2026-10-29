import SwiftUI
import LumiUI
import KitMail

/// 账户添加/编辑表单。
///
/// - 服务商预设选择后自动预填 IMAP/SMTP 主机与端口；
/// - 「连接测试」用当前表单值临时建会话（不保存），成功/失败即时反馈；
/// - 保存时密码经 `MailAccountStore` 写入 Keychain，配置 JSON 不含密码。
public struct MailAccountFormView: View {
    @LumiTheme private var theme: any LumiUITheme

    @State private var draft: MailAccountDraft
    private let accountID: UUID?
    private let sessionManager: MailSessionManager
    private let onSave: (MailAccountDraft) -> Void
    private let onCancel: () -> Void

    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var formError: String?

    private enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

    public init(
        initialDraft: MailAccountDraft,
        accountID: UUID?,
        sessionManager: MailSessionManager,
        onSave: @escaping (MailAccountDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._draft = State(initialValue: initialDraft)
        self.accountID = accountID
        self.sessionManager = sessionManager
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            AppSettingSection(
                title: accountID == nil ? "添加账户" : "编辑账户",
                titleAlignment: .leading
            ) {
                providerRow
            }

            AppSettingSection(title: "账户信息", titleAlignment: .leading) {
                VStack(spacing: 0) {
                    AppSettingRow(title: "显示名称（可选）") {
                        AppInputField("显示名称（可选）", text: $draft.displayName)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(title: "邮箱地址") {
                        AppInputField("邮箱地址", text: $draft.email)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(title: "登录用户名") {
                        AppInputField("登录用户名", text: $draft.username)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(title: "密码 / 授权码") {
                        GlassTextField(
                            title: "",
                            text: $draft.password,
                            placeholder: "应用专用密码或授权码",
                            isSecure: true,
                            allowsReveal: true
                        )
                    }
                }
            }

            AppSettingSection(title: "服务器", titleAlignment: .leading) {
                VStack(spacing: 0) {
                    serverHostRow("IMAP 服务器", host: $draft.imapHost)

                    Divider()
                        .padding(.vertical, 8)

                    portRow("IMAP 端口", port: $draft.imapPort)

                    Divider()
                        .padding(.vertical, 8)

                    serverHostRow("SMTP 服务器", host: $draft.smtpHost)

                    Divider()
                        .padding(.vertical, 8)

                    portRow("SMTP 端口", port: $draft.smtpPort)

                    Divider()
                        .padding(.vertical, 8)

                    AppSettingToggleRow("强制 TLS", isOn: $draft.useTLS)
                }
            }

            AppSettingSection(title: nil, titleAlignment: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    testRow
                    if let formError {
                        Text(formError)
                            .font(.appCaption)
                            .foregroundColor(theme.error)
                    }
                    actionsRow
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 服务商预设

    private var providerRow: some View {
        AppSettingRow(title: "服务商", icon: "server.rack") {
            Picker("服务商", selection: $draft.provider) {
                ForEach(MailProviderPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .onChange(of: draft.provider) { _, newValue in
            draft.applyPresetDefaults()
        }
    }

    // MARK: - 服务器字段

    private func serverHostRow(_ title: String, host: Binding<String>) -> some View {
        AppSettingRow(title: title) {
            AppInputField(LocalizedStringKey(title), text: host)
        }
    }

    private func portRow(_ title: String, port: Binding<Int>) -> some View {
        AppSettingRow(title: title) {
            TextField(
                title,
                value: port,
                format: .number
            )
            .textFieldStyle(.plain)
        }
    }

    // MARK: - 连接测试

    private var testRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AppButton(
                    isTesting ? "测试中…" : "连接测试",
                    style: .secondary,
                    fillsWidth: true
                ) {
                    Task { await runTest() }
                }
                .disabled(isTesting)
                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            resultBanner
        }
    }

    @ViewBuilder
    private var resultBanner: some View {
        if let testResult {
            switch testResult {
            case .success(let message):
                Text("✓ \(message)")
                    .font(.appCaption)
                    .foregroundColor(theme.success)
            case .failure(let message):
                Text("⚠ \(message)")
                    .font(.appCaption)
                    .foregroundColor(theme.error)
            }
        }
    }

    // MARK: - 操作

    private var actionsRow: some View {
        HStack(spacing: 8) {
            AppButton("取消", style: .secondary, fillsWidth: true) {
                onCancel()
            }
            AppButton(
                "保存",
                style: .primary,
                fillsWidth: true
            ) {
                save()
            }
        }
    }

    private func runTest() async {
        isTesting = true
        testResult = nil
        formError = nil
        defer { isTesting = false }

        guard !draft.email.isEmpty, !draft.password.isEmpty else {
            formError = "请先填写邮箱地址与密码/授权码。"
            return
        }
        let config = draft.toConfig(id: accountID ?? UUID())
        do {
            try await sessionManager.testConnection(account: config, password: draft.password)
            testResult = .success("连接成功：认证通过。")
        } catch {
            testResult = .failure("连接失败：\(error.localizedDescription)")
        }
    }

    private func save() {
        formError = nil
        guard !draft.email.isEmpty else {
            formError = "邮箱地址不能为空。"
            return
        }
        guard !draft.password.isEmpty else {
            formError = "请填写密码/授权码。"
            return
        }
        guard !draft.imapHost.isEmpty, !draft.smtpHost.isEmpty else {
            formError = "IMAP 与 SMTP 服务器不能为空。"
            return
        }
        onSave(draft)
    }
}
