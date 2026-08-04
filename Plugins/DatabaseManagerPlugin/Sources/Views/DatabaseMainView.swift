import SwiftUI
import LumiUI
import LumiKernel

/// 主面板：Query 编辑器 + 结果区。
///
/// 表/键浏览已迁移到 RailView（`DatabaseSidebarView`），
/// 本视图仅负责数据展示和查询操作。
/// 连接管理迁到了工具栏右上角 `DatabaseToolbarButton` 的 popover。
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
            tableDataSection
        } else {
            VStack(spacing: 0) {
                queryEditor
                toolbar
                AppDivider()
                resultsSection
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var tableDataSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedSQLiteTable ?? LumiPluginLocalization.string("Select a table", bundle: .module))
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    if viewModel.selectedSQLiteTable != nil {
                        Text("First 50 rows")
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer()
                if viewModel.selectedSQLiteTable != nil {
                    AppButton("Refresh", systemImage: "arrow.clockwise", style: .secondary, size: .small, action: {
                        guard let table = viewModel.selectedSQLiteTable else { return }
                        Task { await viewModel.openSQLiteTable(table) }
                    })
                }
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .appSurface(style: .toolbar, cornerRadius: 0)

            AppDivider()
            resultsSection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    @ViewBuilder
    private var resultsSection: some View {
        if let error = viewModel.errorMessage {
            AppErrorBanner(message: LocalizedStringKey(error))
                .padding(12)
        } else if let result = viewModel.queryResult {
            QueryResultView(result: result)
        } else {
            AppEmptyState(
                icon: viewModel.selectedSQLiteTable == nil ? "tablecells" : "tray",
                title: viewModel.selectedSQLiteTable == nil
                    ? LumiPluginLocalization.string("Select a table", bundle: .module)
                    : LumiPluginLocalization.string("No results", bundle: .module),
                description: viewModel.selectedSQLiteTable == nil
                    ? LumiPluginLocalization.string("Choose a table from the sidebar to view its data.", bundle: .module)
                    : nil
            )
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
