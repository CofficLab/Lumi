import LumiKernel
import LumiUI
import SwiftUI

/// 主面板：Query 编辑器 + 结果区。
///
/// 表/键浏览已迁移到 RailView（`DatabaseSidebarView`），
/// 本视图仅负责数据展示和查询操作。
/// 连接管理迁到了工具栏右上角 `DatabaseToolbarButton` 的 popover。
public struct MainView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 由 ``DatabaseManagerPlugin`` 注入，与 ``DatabaseToolbarButton`` 共享同一个实例，
    /// 这样在工具栏 popover 中选中/断开连接会立即反映到主面板。
    @ObservedObject var viewModel: DatabaseViewModel

    /// 由本视图的「去添加」按钮触发；popover 中的 Add Connection 共享同一个表单。
    @State private var showAddConfigSheet = false

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.isConnected {
                connectedContent
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAddConfigSheet) {
            AddConnectionView(viewModel: viewModel, isPresented: $showAddConfigSheet)
        }
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedContent: some View {
        if viewModel.selectedConfig?.type == .sqlite {
            SQLiteTableView(viewModel: viewModel)
        } else {
            VStack(spacing: 0) {
                queryEditor
                toolbar
                AppDivider()
                QueryResultSectionView(viewModel: viewModel)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var queryEditor: some View {
        TextEditor(text: $viewModel.queryText)
            .font(.monospaced(.body)())
            .padding(8)
            .frame(minHeight: 100, maxHeight: 200)
            .border(theme.appSubtleBorder)
    }

    private var toolbar: some View {
        AppToolbarContainer(height: 48) {
            HStack {
                Spacer()
                if viewModel.isConnected {
                    AppButton("Disconnect", systemImage: "bolt.horizontal.circle", style: .secondary, size: .small, action: { Task { await viewModel.disconnect() } })
                }
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                AppButton("Run", systemImage: "play.fill", style: .primary, size: .small, action: { Task { await viewModel.executeQuery() } })
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        MainEmptyStateView(viewModel: viewModel, onAddConnection: { showAddConfigSheet = true })
    }
}


public struct AddConnectionView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: DatabaseViewModel
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var type: DatabaseType = .sqlite
    @State private var host = ""
    @State private var portText = ""
    @State private var database = ""
    @State private var username = ""
    @State private var password = ""
    @State private var sqlitePath = ""
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var testSuccess = false

    public var body: some View {
        VStack(spacing: 20) {
            Text(LumiPluginLocalization.string("Add Connection", bundle: .module))
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)

            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    GlassTextField(title: "Connection Name", text: $name, placeholder: "My Database")

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
                    }

                    if type == .sqlite {
                        GlassTextField(title: "Database Path", text: $sqlitePath, placeholder: "/path/to/db.sqlite")
                    } else {
                        GlassTextField(title: "Host", text: $host, placeholder: "127.0.0.1")
                        GlassTextField(title: "Port", text: $portText, placeholder: type == .redis ? "6379" : (type == .postgresql ? "5432" : "3306"))
                        if type != .redis {
                            GlassTextField(title: "Database", text: $database, placeholder: type == .postgresql ? "postgres" : "test")
                            GlassTextField(title: "Username", text: $username, placeholder: "user")
                        }
                        GlassTextField(title: "Password", text: $password, placeholder: "••••••••", isSecure: true)
                    }
                }
            }

            HStack {
                AppButton("Cancel", style: .ghost, fillsWidth: true, action: { isPresented = false })
                AppButton("Test Connection", style: .secondary, fillsWidth: true, action: {
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
                            testMessage = "连接成功"
                            testSuccess = true
                        } catch {
                            testMessage = error.localizedDescription
                            testSuccess = false
                        }
                        isTesting = false
                    }
                })
                .disabled(!canTestConnection())
                AppButton("Add", style: .primary, fillsWidth: true, action: {
                    do {
                        viewModel.addConfig(try makeConnectionConfig())
                        isPresented = false
                    } catch {
                        testMessage = error.localizedDescription
                        testSuccess = false
                    }
                })
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
    }

    private func isValid() -> Bool {
        (try? makeConnectionConfig()) != nil
    }

    private func canTestConnection() -> Bool {
        (try? makeConnectionConfig(defaultName: "Test")) != nil
    }

    private func makeConnectionConfig(defaultName: String? = nil) throws -> DatabaseConfig {
        try DatabaseConnectionDraft(
            name: name,
            type: type,
            host: host,
            portText: portText,
            database: database,
            username: username,
            password: password,
            sqlitePath: sqlitePath
        ).makeConfig(defaultName: defaultName)
    }
}

// MARK: - Preview
