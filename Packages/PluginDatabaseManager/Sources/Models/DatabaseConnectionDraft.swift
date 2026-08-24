import Foundation

enum DatabaseConnectionDraftError: LocalizedError, Equatable {
    case missingName
    case missingSQLitePath
    case missingHost
    case invalidPort
    case missingDatabase
    case missingUsername

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Connection name is required."
        case .missingSQLitePath:
            return "SQLite database path is required."
        case .missingHost:
            return "Host is required."
        case .invalidPort:
            return "Port must be a number from 1 to 65535."
        case .missingDatabase:
            return "Database name is required."
        case .missingUsername:
            return "Username is required."
        }
    }
}

struct DatabaseConnectionDraft {
    var name: String
    var type: DatabaseType
    var host: String
    var portText: String
    var database: String
    var username: String
    var password: String
    var sqlitePath: String

    func makeConfig(defaultName: String? = nil) throws -> DatabaseConfig {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let configName: String
        if trimmedName.isEmpty, let defaultName {
            configName = defaultName
        } else if trimmedName.isEmpty {
            throw DatabaseConnectionDraftError.missingName
        } else {
            configName = trimmedName
        }

        switch type {
        case .sqlite:
            let path = sqlitePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                throw DatabaseConnectionDraftError.missingSQLitePath
            }
            return DatabaseConfig(
                name: configName,
                type: type,
                database: path,
                password: password.isEmpty ? nil : password
            )
        case .redis:
            return DatabaseConfig(
                name: configName,
                type: type,
                host: try normalizedHost(),
                port: try normalizedPort(),
                database: "",
                password: password.isEmpty ? nil : password
            )
        case .postgresql, .mysql:
            let databaseName = database.trimmingCharacters(in: .whitespacesAndNewlines)
            let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !databaseName.isEmpty else {
                throw DatabaseConnectionDraftError.missingDatabase
            }
            guard !user.isEmpty else {
                throw DatabaseConnectionDraftError.missingUsername
            }
            return DatabaseConfig(
                name: configName,
                type: type,
                host: try normalizedHost(),
                port: try normalizedPort(),
                database: databaseName,
                username: user,
                password: password.isEmpty ? nil : password
            )
        }
    }

    private func normalizedHost() throws -> String {
        let value = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw DatabaseConnectionDraftError.missingHost
        }
        return value
    }

    private func normalizedPort() throws -> Int {
        guard let port = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(port) else {
            throw DatabaseConnectionDraftError.invalidPort
        }
        return port
    }
}
