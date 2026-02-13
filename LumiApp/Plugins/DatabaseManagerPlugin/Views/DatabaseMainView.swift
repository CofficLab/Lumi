import SwiftUI

struct DatabaseMainView: View {
    @StateObject private var viewModel = DatabaseViewModel()
    @State private var showAddConfigSheet = false
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading) {
                Text("Connections")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .padding(.horizontal)
                    .padding(.top)
                
                List(viewModel.configs, id: \.id) { config in
                    HStack {
                        Image(systemName: "server.rack")
                        Text(config.name)
                        Spacer()
                        if viewModel.selectedConfig?.id == config.id && viewModel.isConnected {
                            Circle()
                                .fill(DesignTokens.Color.semantic.success)
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
                
                GlassButton(title: "Add Connection", style: .primary) {
                    showAddConfigSheet = true
                }
                .padding()
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Main Content
            VStack {
                if viewModel.isConnected {
                    VStack(spacing: 0) {
                        if viewModel.selectedConfig?.type == .redis {
                            MystiqueGlassCard {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    HStack {
                                        Text("Keys")
                                            .font(.headline)
                                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                        Spacer()
                                        GlassButton(title: "Load", style: .secondary) {
                                            Task { await viewModel.loadRedisKeys() }
                                        }
                                    }
                                    List(viewModel.redisKeys, id: \.self) { key in
                                        HStack {
                                            Image(systemName: "key")
                                            Text(key)
                                            Spacer()
                                            GlassButton(title: "Open", style: .ghost) {
                                                Task { await viewModel.openRedisKey(key) }
                                            }
                                        }
                                    }
                                    .frame(minHeight: 120, maxHeight: 200)
                                }
                            }
                            GlassDivider()
                        }
                        if viewModel.selectedConfig?.type == .sqlite {
                            MystiqueGlassCard {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    HStack {
                                        Text("Tables")
                                            .font(.headline)
                                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                        Spacer()
                                        GlassButton(title: "Load", style: .secondary) {
                                            Task { await viewModel.loadSQLiteTables() }
                                        }
                                    }
                                    List(viewModel.sqliteTables, id: \.self) { table in
                                        HStack {
                                            Image(systemName: "tablecells")
                                            Text(table)
                                            Spacer()
                                            GlassButton(title: "Open", style: .ghost) {
                                                Task { await viewModel.openSQLiteTable(table) }
                                            }
                                        }
                                    }
                                    .frame(minHeight: 120, maxHeight: 200)
                                }
                            }
                            GlassDivider()
                        }
                        // Query Editor
                        TextEditor(text: $viewModel.queryText)
                            .font(.monospaced(.body)())
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 200)
                            .border(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                        
                        // Toolbar
                        HStack {
                            Spacer()
                            if viewModel.isConnected {
                                GlassButton(title: "Disconnect", style: .secondary) {
                                    Task { await viewModel.disconnect() }
                                }
                            }
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                            GlassButton(title: "Run", style: .primary) {
                                Task { await viewModel.executeQuery() }
                            }
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                        .padding(8)
                        .background(DesignTokens.Material.glass)
                        
                        GlassDivider()
                        
                        // Results
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(DesignTokens.Color.semantic.error)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let result = viewModel.queryResult {
                            QueryResultView(result: result)
                        } else {
                            Text("No results")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    VStack {
                        Image(systemName: "database")
                            .font(.system(size: 48))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("Select a database to connect")
                            .font(.title2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showAddConfigSheet) {
            AddConnectionView(viewModel: viewModel, isPresented: $showAddConfigSheet)
        }
    }
}

struct QueryResultView: View {
    let result: QueryResult
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(result.columns, id: \.self) { col in
                        Text(col)
                            .font(.headline)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            .padding(8)
                            .frame(width: 120, alignment: .leading)
                            .border(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                    }
                }
                .background(DesignTokens.Material.glass)
                
                // Rows
                LazyVStack(spacing: 0) {
                    ForEach(0..<result.rows.count, id: \.self) { rowIndex in
                        let row = result.rows[rowIndex]
                        HStack(spacing: 0) {
                            ForEach(0..<row.count, id: \.self) { colIndex in
                                let text = content(for: row[colIndex])
                                Text(text)
                                    .font(.monospaced(.body)())
                                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                    .padding(8)
                                    .frame(width: 160, alignment: .leading)
                                    .border(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
                                    .contextMenu {
                                        Button("Copy") {
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
    
    func content(for value: DatabaseValue) -> String {
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

struct AddConnectionView: View {
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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Connection")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            
            MystiqueGlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    GlassTextField(title: "Connection Name", text: $name, placeholder: "My Database")
                    
                    HStack {
                        Text("Database Type")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
                GlassButton(title: "Cancel", style: .ghost) { isPresented = false }
                GlassButton(title: "Test Connection", style: .secondary) {
                    isTesting = true
                    testMessage = nil
                    testSuccess = false
                    let port = Int(portText)
                    let config = DatabaseConfig(
                        name: name.isEmpty ? "Test" : name,
                        type: type,
                        host: type == .sqlite ? nil : host,
                        port: type == .sqlite ? nil : port,
                        database: type == .sqlite ? sqlitePath : (type == .redis ? "" : database),
                        username: type == .sqlite || type == .redis ? nil : username,
                        password: password.isEmpty ? nil : password,
                        options: nil
                    )
                    Task {
                        do {
                            try await DatabaseManager.shared.probe(config: config)
                            testMessage = "连接成功"
                            testSuccess = true
                        } catch {
                            testMessage = error.localizedDescription
                            testSuccess = false
                        }
                        isTesting = false
                    }
                }
                GlassButton(title: "Add", style: .primary) {
                    let port = Int(portText)
                    let config = DatabaseConfig(
                        name: name,
                        type: type,
                        host: type == .sqlite ? nil : host,
                        port: type == .sqlite ? nil : port,
                        database: type == .sqlite ? sqlitePath : (type == .redis ? "" : database),
                        username: type == .sqlite || type == .redis ? nil : username,
                        password: password.isEmpty ? nil : password,
                        options: nil
                    )
                    viewModel.configs.append(config)
                    isPresented = false
                }
                .disabled(!isValid())
            }
            
            if let msg = testMessage {
                HStack {
                    Image(systemName: testSuccess ? "checkmark.circle" : "xmark.octagon")
                        .foregroundColor(testSuccess ? DesignTokens.Color.semantic.success : DesignTokens.Color.semantic.error)
                    Text(msg)
                        .foregroundColor(testSuccess ? DesignTokens.Color.semantic.success : DesignTokens.Color.semantic.error)
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
        guard !name.isEmpty else { return false }
        switch type {
        case .sqlite:
            return !sqlitePath.isEmpty
        case .redis:
            return !host.isEmpty && (Int(portText) ?? 0) > 0
        case .postgresql, .mysql:
            return !host.isEmpty && (Int(portText) ?? 0) > 0 && !database.isEmpty && !username.isEmpty
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
