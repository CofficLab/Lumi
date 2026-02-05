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
                    .padding(.horizontal)
                    .padding(.top)
                
                List(viewModel.configs, id: \.id) { config in
                    HStack {
                        Image(systemName: "server.rack")
                        Text(config.name)
                        Spacer()
                        if viewModel.selectedConfig?.id == config.id && viewModel.isConnected {
                            Circle()
                                .fill(Color.green)
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
                
                Button(action: { showAddConfigSheet = true }) {
                    Label("Add Connection", systemImage: "plus")
                }
                .padding()
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Main Content
            VStack {
                if viewModel.isConnected {
                    VStack(spacing: 0) {
                        // Query Editor
                        TextEditor(text: $viewModel.queryText)
                            .font(.monospaced(.body)())
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 200)
                            .border(Color.gray.opacity(0.2))
                        
                        // Toolbar
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                            Button(action: { Task { await viewModel.executeQuery() } }) {
                                Label("Run", systemImage: "play.fill")
                            }
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        
                        Divider()
                        
                        // Results
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let result = viewModel.queryResult {
                            QueryResultView(result: result)
                        } else {
                            Text("No results")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    VStack {
                        Image(systemName: "database")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Select a database to connect")
                            .font(.title2)
                            .foregroundColor(.secondary)
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
                            .padding(8)
                            .frame(width: 120, alignment: .leading)
                            .border(Color.gray.opacity(0.2))
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                
                // Rows
                LazyVStack(spacing: 0) {
                    ForEach(0..<result.rows.count, id: \.self) { rowIndex in
                        let row = result.rows[rowIndex]
                        HStack(spacing: 0) {
                            ForEach(0..<row.count, id: \.self) { colIndex in
                                Text(content(for: row[colIndex]))
                                    .font(.monospaced(.body)())
                                    .padding(8)
                                    .frame(width: 120, alignment: .leading)
                                    .border(Color.gray.opacity(0.1))
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
    @State private var path = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add SQLite Connection")
                .font(.headline)
            
            TextField("Connection Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            TextField("Database Path (or :memory:)", text: $path)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") { isPresented = false }
                Button("Add") {
                    let config = DatabaseConfig(name: name, type: .sqlite, database: path)
                    viewModel.configs.append(config)
                    isPresented = false
                }
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
