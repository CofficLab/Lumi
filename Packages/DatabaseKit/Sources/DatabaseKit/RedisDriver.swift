import Foundation
import Network

enum RespValue: Equatable {
    case simpleString(String)
    case error(String)
    case integer(Int)
    case bulkString(Data?)
    case array([RespValue]?)
}

enum RedisRESPCodec {
    static func encodeCommand(_ args: [String]) -> Data {
        var out = "*\(args.count)\r\n"
        for arg in args {
            let utf8Count = arg.data(using: .utf8)?.count ?? arg.count
            out += "$\(utf8Count)\r\n"
            out += arg
            out += "\r\n"
        }
        return Data(out.utf8)
    }

    static func parse(_ data: Data) throws -> RespValue {
        var parser = Parser(data: data)
        return try parser.parseValue()
    }

    private struct Parser {
        let data: Data
        var offset: Data.Index

        init(data: Data) {
            self.data = data
            self.offset = data.startIndex
        }

        mutating func parseValue() throws -> RespValue {
            guard offset < data.endIndex else {
                return .bulkString(nil)
            }

            let prefix = data[offset]
            offset = data.index(after: offset)

            switch prefix {
            case UInt8(ascii: "+"):
                return .simpleString(try readLine())
            case UInt8(ascii: "-"):
                return .error(try readLine())
            case UInt8(ascii: ":"):
                return .integer(Int(try readLine()) ?? 0)
            case UInt8(ascii: "$"):
                let length = Int(try readLine()) ?? -1
                guard length >= 0 else { return .bulkString(nil) }
                let content = try readData(length: length)
                try consumeCRLF()
                return .bulkString(content)
            case UInt8(ascii: "*"):
                let count = Int(try readLine()) ?? -1
                guard count >= 0 else { return .array(nil) }
                var values: [RespValue] = []
                values.reserveCapacity(count)
                for _ in 0..<count {
                    values.append(try parseValue())
                }
                return .array(values)
            default:
                return .bulkString(Data([prefix]) + data[offset...])
            }
        }

        private mutating func readLine() throws -> String {
            let start = offset
            while offset < data.endIndex {
                if data[offset] == UInt8(ascii: "\r") {
                    let next = data.index(after: offset)
                    guard next < data.endIndex, data[next] == UInt8(ascii: "\n") else {
                        throw DatabaseError.queryFailed("Malformed RESP line ending")
                    }
                    let lineData = data[start..<offset]
                    offset = data.index(after: next)
                    return String(decoding: lineData, as: UTF8.self)
                }
                offset = data.index(after: offset)
            }
            throw DatabaseError.queryFailed("Unexpected end of RESP payload")
        }

        private mutating func readData(length: Int) throws -> Data {
            guard length >= 0 else { return Data() }
            let end = data.index(offset, offsetBy: length, limitedBy: data.endIndex) ?? data.endIndex
            guard data.distance(from: offset, to: end) == length else {
                throw DatabaseError.queryFailed("Incomplete RESP bulk string")
            }
            let chunk = data[offset..<end]
            offset = end
            return Data(chunk)
        }

        private mutating func consumeCRLF() throws {
            guard offset < data.endIndex, data[offset] == UInt8(ascii: "\r") else {
                throw DatabaseError.queryFailed("Missing RESP CRLF")
            }
            let next = data.index(after: offset)
            guard next < data.endIndex, data[next] == UInt8(ascii: "\n") else {
                throw DatabaseError.queryFailed("Missing RESP LF")
            }
            offset = data.index(after: next)
        }
    }
}

public final class RedisDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .redis }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        guard let host = config.host, !host.isEmpty else {
            throw DatabaseError.invalidConfiguration("Redis 需要有效的主机地址")
        }
        let port = config.port ?? 6379
        return try await RedisConnection(host: host, port: port, password: config.password)
    }
}

public actor RedisConnection: DatabaseConnection {
    private let connection: NWConnection
    private var alive = false

    public init(host: String, port: Int = 6379, password: String? = nil) async throws {
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )

        connection.start(queue: DispatchQueue(label: "databasekit.redis.connection"))
        try await waitForReady()
        alive = true

        if let password, !password.isEmpty {
            _ = try await send(["AUTH", password])
        }
        _ = try await send(["PING"])
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard alive else { throw DatabaseError.connectionFailed("Redis 连接未就绪") }
        let response = try await send(tokenize(sql))
        switch response {
        case .simpleString(let value) where value.uppercased() == "OK":
            return 1
        case .integer(let value):
            return value
        case .bulkString, .array:
            return 1
        case .error(let error):
            throw DatabaseError.queryFailed(error)
        default:
            return 0
        }
    }

    public func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        guard alive else { throw DatabaseError.connectionFailed("Redis 连接未就绪") }
        let args = tokenize(sql)
        let command = args.first?.uppercased() ?? ""
        let response = try await send(args)

        switch command {
        case "GET":
            let key = args.count > 1 ? args[1] : ""
            let valueString: String
            switch response {
            case .bulkString(let data):
                valueString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "NULL"
            case .simpleString(let value):
                valueString = value
            case .integer(let value):
                valueString = String(value)
            case .error(let error):
                throw DatabaseError.queryFailed(error)
            default:
                valueString = "\(response)"
            }
            return QueryResult(columns: ["Key", "Value"], rows: [[.string(key), .string(valueString)]], rowsAffected: 0)

        case "SCAN":
            var keys: [String] = []
            if case .array(let outer?) = response,
               outer.count >= 2,
               case .array(let inner?) = outer[1] {
                keys = inner.compactMap { value in
                    if case .bulkString(let data?) = value {
                        return String(data: data, encoding: .utf8)
                    }
                    return nil
                }
            }
            return QueryResult(columns: ["Key"], rows: keys.map { [.string($0)] }, rowsAffected: 0)

        default:
            switch response {
            case .array(let values):
                return QueryResult(
                    columns: ["Value"],
                    rows: flattenArray(values ?? []).map { [.string($0)] },
                    rowsAffected: 0
                )
            case .bulkString(let data):
                let value = data.flatMap { String(data: $0, encoding: .utf8) } ?? "NULL"
                return QueryResult(columns: ["Value"], rows: [[.string(value)]], rowsAffected: 0)
            case .simpleString(let value):
                return QueryResult(columns: ["Value"], rows: [[.string(value)]], rowsAffected: 0)
            case .integer(let value):
                return QueryResult(columns: ["Value"], rows: [[.integer(value)]], rowsAffected: 0)
            case .error(let error):
                throw DatabaseError.queryFailed(error)
            }
        }
    }

    public func beginTransaction() async throws -> any DatabaseTransaction {
        throw DatabaseError.notImplemented
    }

    public func close() async {
        connection.cancel()
        alive = false
    }

    public func isAlive() async -> Bool {
        alive
    }

    private func waitForReady() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: ())
                case .failed(let error):
                    continuation.resume(throwing: DatabaseError.connectionFailed(error.localizedDescription))
                default:
                    break
                }
            }
        }
    }

    private func tokenize(_ command: String) -> [String] {
        command.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func flattenArray(_ values: [RespValue]) -> [String] {
        var flattened: [String] = []
        for value in values {
            switch value {
            case .bulkString(let data):
                if let data, let string = String(data: data, encoding: .utf8) {
                    flattened.append(string)
                }
            case .simpleString(let string):
                flattened.append(string)
            case .integer(let integer):
                flattened.append(String(integer))
            case .array(let nested):
                flattened.append(contentsOf: flattenArray(nested ?? []))
            case .error(let error):
                flattened.append("ERR: \(error)")
            }
        }
        return flattened
    }

    private func send(_ args: [String]) async throws -> RespValue {
        let data = RedisRESPCodec.encodeCommand(args)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: DatabaseError.queryFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            })
        }

        let received = try await receiveOnce()
        return try RedisRESPCodec.parse(received)
    }

    private func receiveOnce() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: DatabaseError.queryFailed(error.localizedDescription))
                    return
                }
                guard let data else {
                    continuation.resume(throwing: DatabaseError.queryFailed("空响应"))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }
}
