import LumiUI
import SwiftUI

/// 连接表单：同时支持「新建」与「编辑」。
///
/// - 新建：收集字段 → `viewModel.addConfig`。
/// - 编辑：从现有配置回填 → `viewModel.updateConfig`（保留 id；密码留空时沿用旧密码）。
///
/// 编辑模式下的密码处理：表单里始终留空（不回显明文），保存时空值表示「不改密码」。
/// 用户可手动输入新密码来覆盖。
struct ConnectionFormView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: DatabaseViewModel
    @Binding var isPresented: Bool

    /// 编辑模式下的原配置；nil 表示新建。
    let editing: DatabaseConfig?

    @State private var name = ""
    @State private var type: DatabaseType = .sqlite
    @State private var host = ""
    @State private var portText = ""
    @State private var database = ""
    @State private var username = ""
    @State private var password = ""
    @State private var sqlitePath = ""
    @State private var sslOption: ConnectionSSLOption = .require
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var testSuccess = false

    init(viewModel: DatabaseViewModel, isPresented: Binding<Bool>, editing: DatabaseConfig? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.editing = editing
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)

            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    GlassTextField(title: "Connection Name", text: $name, placeholder: LumiPluginLocalization.string("My Database", bundle: .module))

                    HStack {
                        Text(LumiPluginLocalization.string("Database Type", bundle: .module))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Picker("", selection: $type) {
                            ForEach(DatabaseType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .disabled(editing != nil)  // 编辑模式下不切换类型，避免配置语义错乱
                    }

                    if type == .sqlite {
                        GlassTextField(title: LumiPluginLocalization.string("Database Path", bundle: .module), text: $sqlitePath, placeholder: "/path/to/db.sqlite")
                    } else {
                        GlassTextField(title: LumiPluginLocalization.string("Host", bundle: .module), text: $host, placeholder: "127.0.0.1")
                        GlassTextField(title: LumiPluginLocalization.string("Port", bundle: .module), text: $portText, placeholder: "\(type.defaultPort ?? 0)")
                        if type != .redis {
                            GlassTextField(title: LumiPluginLocalization.string("Database", bundle: .module), text: $database, placeholder: type == .postgresql ? "postgres" : "test")
                            GlassTextField(title: LumiPluginLocalization.string("Username", bundle: .module), text: $username, placeholder: "user")
                        }
                        GlassTextField(title: LumiPluginLocalization.string("Password", bundle: .module), text: $password, placeholder: passwordPlaceholder, isSecure: true, allowsReveal: true)

                        if type.capabilities.supportsSSL {
                            sslPicker
                        }
                    }
                }
            }

            HStack {
                AppButton(LumiPluginLocalization.string("Cancel", bundle: .module), style: .ghost, fillsWidth: true, action: { isPresented = false })
                AppButton(LumiPluginLocalization.string("Test Connection", bundle: .module), style: .secondary, fillsWidth: true, action: testConnection)
                    .disabled(!canTestConnection())
                AppButton(saveLabel, style: .primary, fillsWidth: true, action: save)
                    .disabled(!isValid())
            }

            if let msg = testMessage {
                HStack {
                    Image(systemName: testSuccess ? "checkmark.circle" : "xmark.octagon")
                        .foregroundColor(testSuccess ? theme.success : theme.error)
                    Text(msg)
                        .foregroundColor(testSuccess ? theme.success : theme.error)
                    if isTesting {
                        Spacer()
                        ProgressView().scaleEffect(0.5)
                    }
                }
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear(perform: prefill)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sslPicker: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LumiPluginLocalization.string("SSL / TLS", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                Text(sslOption.helpText)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Picker("", selection: $sslOption) {
                ForEach(ConnectionSSLOption.allCases, id: \.self) { mode in
                    Text(mode.displayTitle).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
        }
    }

    // MARK: - Derived

    private var title: String {
        editing == nil
            ? LumiPluginLocalization.string("Add Connection", bundle: .module)
            : LumiPluginLocalization.string("Edit Connection", bundle: .module)
    }

    private var saveLabel: String {
        editing == nil ? "Add" : "Save"
    }

    private var passwordPlaceholder: String {
        editing == nil ? "••••••••" : LumiPluginLocalization.string("Leave blank to keep current", bundle: .module)
    }

    // MARK: - Lifecycle

    private func prefill() {
        guard let editing else { return }
        name = editing.name
        type = editing.type
        host = editing.host ?? ""
        portText = editing.port.map(String.init) ?? ""
        database = editing.database
        username = editing.username ?? ""
        sqlitePath = editing.type == .sqlite ? editing.database : ""
        if let ssl = editing.sslOption {
            sslOption = ssl
        }
    }

    // MARK: - Actions

    private func isValid() -> Bool {
        (try? makeConnectionConfig()) != nil
    }

    private func canTestConnection() -> Bool {
        (try? makeConnectionConfig(defaultName: "Test")) != nil
    }

    private func testConnection() {
        let config: DatabaseConfig
        do {
            config = try makeConnectionConfig(defaultName: "Test")
        } catch {
            testMessage = error.localizedDescription
            testSuccess = false
            return
        }

        isTesting = true
        testMessage = nil
        testSuccess = false
        Task {
            do {
                await DatabaseDriverBootstrap.registerBuiltinsIfNeeded()
                try await DatabaseManagerCore.shared.probe(config: config)
                testMessage = LumiPluginLocalization.string("Connection succeeded", bundle: .module)
                testSuccess = true
            } catch {
                testMessage = error.localizedDescription
                testSuccess = false
            }
            isTesting = false
        }
    }

    private func save() {
        do {
            let config = try makeConnectionConfig()
            if editing != nil {
                // 编辑：保留原 id，把新字段（含 SSL）合并回去
                viewModel.updateConfig(config)
            } else {
                viewModel.addConfig(config)
            }
            isPresented = false
        } catch {
            testMessage = error.localizedDescription
            testSuccess = false
        }
    }

    private func makeConnectionConfig(defaultName: String? = nil) throws -> DatabaseConfig {
        let draft = try DatabaseConnectionDraft(
            name: name,
            type: type,
            host: host,
            portText: portText,
            database: database,
            username: username,
            password: password,
            sqlitePath: sqlitePath
        ).makeConfig(defaultName: defaultName)

        // 编辑模式：保留原 id（makeConfig 会生成新 UUID）
        var config = draft
        if let editing {
            config.id = editing.id
        }
        // SSL 仅对支持 TLS 的网络库有意义
        if type.capabilities.supportsSSL {
            config = config.withSSLOption(sslOption)
        } else {
            config = config.withSSLOption(nil)
        }
        return config
    }
}
