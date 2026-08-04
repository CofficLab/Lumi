import SwiftUI
import LumiUI
import LumiKernel

/// 主面板：表格/键浏览 + Query 编辑器 + 结果区。
///
/// 连接管理迁到了工具栏右上角 `DatabaseToolbarButton` 的 popover，
/// 因此本视图不再渲染连接列表，未连接时显示「去右上角添加连接」的引导。
public struct DatabaseMainView: View {
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
        Group {
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

    private var connectedContent: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左侧：表 / Keys 浏览
            Group {
                if viewModel.selectedConfig?.type == .redis {
                    keysBrowser
                } else if viewModel.selectedConfig?.type == .sqlite {
                    tablesBrowser
                }
            }
            .frame(width: 220, height: .infinity, alignment: .top)

            settingsDivider

            // 右侧：上为 SQL 编辑器 + 工具栏，下为结果
            VStack(spacing: 0) {
                queryEditor
                toolbar
                settingsDivider
                resultsSection
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var keysBrowser: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LumiPluginLocalization.string("Keys", bundle: .module))
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    AppButton("Load", style: .secondary, fillsWidth: true, action: { Task { await viewModel.loadRedisKeys() } })
                }
                List(viewModel.redisKeys, id: \.self) { key in
                    HStack {
                        Image(systemName: "key")
                        Text(key)
                        Spacer()
                        AppButton("Open", style: .ghost, fillsWidth: true, action: { Task { await viewModel.openRedisKey(key) } })
                    }
                }
                .frame(minHeight: 120, maxHeight: 200)
            }
        }
    }

    private var tablesBrowser: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LumiPluginLocalization.string("Tables", bundle: .module))
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    AppButton("Load", style: .secondary, fillsWidth: true, action: { Task { await viewModel.loadSQLiteTables() } })
                }
                List(viewModel.sqliteTables, id: \.self) { table in
                    HStack {
                        Image(systemName: "tablecells")
                        Text(table)
                        Spacer()
                        AppButton("Open", style: .ghost, fillsWidth: true, action: { Task { await viewModel.openSQLiteTable(table) } })
                    }
                }
                .frame(minHeight: 120, maxHeight: 200)
            }
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
        HStack {
            Spacer()
            if viewModel.isConnected {
                AppButton("Disconnect", style: .secondary, fillsWidth: true, action: { Task { await viewModel.disconnect() } })
            }
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            }
            AppButton("Run", style: .primary, fillsWidth: true, action: { Task { await viewModel.executeQuery() } })
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(8)
        .background(Material.regularMaterial)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(theme.error)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let result = viewModel.queryResult {
            QueryResultView(result: result)
        } else {
            Text(LumiPluginLocalization.string("No results", bundle: .module))
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cylinder.split.1x2")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)
            Text(LumiPluginLocalization.string("Select a database to connect", bundle: .module))
                .font(.appTitle)
                .foregroundColor(theme.textSecondary)
            Text(LumiPluginLocalization.string("Use the toolbar button at the top right to manage connections.", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            AppButton(
                LumiPluginLocalization.string("Add Connection", bundle: .module),
                style: .primary,
                fillsWidth: false,
                action: { showAddConfigSheet = true }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(theme.appDivider)
            .frame(height: 1)
    }
}

public struct QueryResultView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let result: QueryResult
    
    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(result.columns, id: \.self) { col in
                        Text(col)
                            .font(.appBodyEmphasized)
                            .foregroundColor(theme.textPrimary)
                            .padding(8)
                            .frame(width: 120, alignment: .leading)
                            .border(theme.appSubtleBorder)
                    }
                }
                .background(Material.regularMaterial)
                
                // Rows
                LazyVStack(spacing: 0) {
                    ForEach(0..<result.rows.count, id: \.self) { rowIndex in
                        let row = result.rows[rowIndex]
                        HStack(spacing: 0) {
                            ForEach(0..<row.count, id: \.self) { colIndex in
                                let text = content(for: row[colIndex])
                                Text(text)
                                    .font(.monospaced(.body)())
                                    .foregroundColor(theme.textPrimary)
                                    .padding(8)
                                    .frame(width: 160, alignment: .leading)
                                    .border(theme.appSubtleBorder.opacity(0.7))
                                    .contextMenu {
                                        Button(LumiPluginLocalization.string("Copy", bundle: .module)) {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(text, forType: .string)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func content(for value: DatabaseValue) -> String {
        switch value {
        case .integer(let v): return String(v)
        case .double(let v): return String(v)
        case .string(let v): return v
        case .bool(let v): return String(v)
        case .data(let v): return "<BLOB \(v.count) bytes>"
        case .null: return "NULL"
        }
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
