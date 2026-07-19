import SwiftUI
import LumiUI
import LumiKernel

public struct DatabaseMainView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel = DatabaseViewModel()
    @State private var showAddConfigSheet = false
    
    public var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading) {
                Text(LumiPluginLocalization.string("Connections", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal)
                    .padding(.top)
                
                List(viewModel.configs, id: \.id) { config in
                    HStack {
                        Image(systemName: "server.rack")
                        Text(config.name)
                        Spacer()
                        if viewModel.selectedConfig?.id == config.id && viewModel.isConnected {
                            Circle()
                                .fill(theme.success)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.selectedConfig?.id != config.id {
                            Task { await viewModel.connect(config: config) }
                        }
                    }
                }
                .listStyle(.sidebar)
                
                AppButton("Add Connection", style: .primary, fillsWidth: true, action: { showAddConfigSheet = true })
                .padding()
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Main Content
            VStack {
                if viewModel.isConnected {
                    VStack(spacing: 0) {
                        if viewModel.selectedConfig?.type == .redis {
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
                            settingsDivider
                        }
                        if viewModel.selectedConfig?.type == .sqlite {
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
                            settingsDivider
                        }
                        // Query Editor
                        TextEditor(text: $viewModel.queryText)
                            .font(.monospaced(.body)())
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 200)
                            .border(theme.appSubtleBorder)
                        
                        // Toolbar
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
                        
                        settingsDivider
                        
                        // Results
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
                } else {
                    VStack {
                        Image(systemName: "database")
                            .font(.appLargeTitle)
                            .foregroundColor(theme.textSecondary)
                        Text(LumiPluginLocalization.string("Select a database to connect", bundle: .module))
                            .font(.appTitle)
                            .foregroundColor(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showAddConfigSheet) {
            AddConnectionView(viewModel: viewModel, isPresented: $showAddConfigSheet)
        }
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
