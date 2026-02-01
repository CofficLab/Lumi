import Foundation
import Combine

@MainActor
class DatabaseViewModel: ObservableObject {
    @Published var configs: [DatabaseConfig] = []
    @Published var selectedConfig: DatabaseConfig?
    @Published var queryText: String = "SELECT * FROM sqlite_master;"
    @Published var queryResult: QueryResult?
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    
    private let manager = DatabaseManager.shared
    
    init() {
        // Load mock config
        configs.append(DatabaseConfig(name: "Demo SQLite", type: .sqlite, database: ":memory:")) // In-memory DB
    }
    
    func connect(config: DatabaseConfig) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await manager.connect(config: config)
            selectedConfig = config
            isConnected = true
            
            // Create some demo data if in-memory
            if config.database == ":memory:" {
                try await initDemoData(configId: config.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func disconnect() async {
        guard let config = selectedConfig else { return }
        await manager.disconnect(configId: config.id)
        isConnected = false
        selectedConfig = nil
        queryResult = nil
    }
    
    func executeQuery() async {
        guard let config = selectedConfig, let connection = await manager.getConnection(for: config.id) else {
            errorMessage = "Not connected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if queryText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("SELECT") ||
               queryText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("PRAGMA") {
                let result = try await connection.query(queryText, params: nil)
                queryResult = result
            } else {
                let affected = try await connection.execute(queryText, params: nil)
                queryResult = QueryResult(columns: ["Result"], rows: [[ "Success. Rows affected: \(affected)" ]], rowsAffected: affected)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func initDemoData(configId: UUID) async throws {
        guard let connection = await manager.getConnection(for: configId) else { return }
        _ = try await connection.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, email TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: ["Alice", "alice@example.com"])
        _ = try await connection.execute("INSERT INTO users (name, email) VALUES (?, ?)", params: ["Bob", "bob@example.com"])
    }
}
