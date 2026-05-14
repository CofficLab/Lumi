import Foundation
import Network

enum RespValue: Equatable {
    case simpleString(String)
    case error(String)
    case integer(Int)
    case bulkString(Data?)
    case array([RespValue]?)
}

enum RedisRESPParseError: Error, Equatable {
    case incomplete
    case malformed(String)
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
        do {
            let value = try parser.parseValue()
            guard parser.isAtEnd else {
                throw RedisRESPParseError.malformed("Unexpected trailing RESP data")
            }
            return value
        } catch RedisRESPParseError.incomplete {
            throw DatabaseError.queryFailed("Incomplete RESP payload")
        } catch RedisRESPParseError.malformed(let message) {
            throw DatabaseError.queryFailed(message)
        }
    }

    static func parseComplete(_ data: Data) throws -> RespValue? {
        var parser = Parser(data: data)
        do {
            let value = try parser.parseValue()
            guard parser.isAtEnd else {
                throw RedisRESPParseError.malformed("Unexpected trailing RESP data")
            }
            return value
        } catch RedisRESPParseError.incomplete {
            return nil
        } catch RedisRESPParseError.malformed(let message) {
            throw DatabaseError.queryFailed(message)
        }
    }

    private struct Parser {
        let data: Data
        var offset: Data.Index

        init(data: Data) {
            self.data = data
            self.offset = data.startIndex
        }

        var isAtEnd: Bool {
            offset == data.endIndex
        }

        mutating func parseValue() throws -> RespValue {
            guard offset < data.endIndex else {
                throw RedisRESPParseError.incomplete
            }

            let prefix = data[offset]
            offset = data.index(after: offset)

            switch prefix {
            case UInt8(ascii: "+"):
                return .simpleString(try readLine())
            case UInt8(ascii: "-"):
                return .error(try readLine())
            case UInt8(ascii: ":"):
                let line = try readLine()
                guard let integer = Int(line) else {
                    throw RedisRESPParseError.malformed("Invalid RESP integer")
                }
                return .integer(integer)
            case UInt8(ascii: "$"):
                guard let length = Int(try readLine()) else {
                    throw RedisRESPParseError.malformed("Invalid RESP bulk string length")
                }
                guard length >= 0 else { return .bulkString(nil) }
                let content = try readData(length: length)
                try consumeCRLF()
                return .bulkString(content)
            case UInt8(ascii: "*"):
                guard let count = Int(try readLine()) else {
                    throw RedisRESPParseError.malformed("Invalid RESP array length")
                }
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
                        throw RedisRESPParseError.malformed("Malformed RESP line ending")
                    }
                    let lineData = data[start..<offset]
                    offset = data.index(after: next)
                    return String(decoding: lineData, as: UTF8.self)
                }
                offset = data.index(after: offset)
            }
            throw RedisRESPParseError.incomplete
        }

        private mutating func readData(length: Int) throws -> Data {
            guard length >= 0 else { return Data() }
            let end = data.index(offset, offsetBy: length, limitedBy: data.endIndex) ?? data.endIndex
            guard data.distance(from: offset, to: end) == length else {
                throw RedisRESPParseError.incomplete
            }
            let chunk = data[offset..<end]
            offset = end
            return Data(chunk)
        }

        private mutating func consumeCRLF() throws {
            guard offset < data.endIndex, data[offset] == UInt8(ascii: "\r") else {
                throw RedisRESPParseError.incomplete
            }
            let next = data.index(after: offset)
            guard next < data.endIndex, data[next] == UInt8(ascii: "\n") else {
                throw RedisRESPParseError.incomplete
            }
            offset = data.index(after: next)
        }
    }
}

enum RedisCommandParser {
    static func tokenize(_ command: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var isEscaping = false
        var hasTokenContent = false

        for character in command {
            if isEscaping {
                current.append(character)
                hasTokenContent = true
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                hasTokenContent = true
                continue
            }

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                    hasTokenContent = true
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                hasTokenContent = true
                continue
            }

            if character.isWhitespace {
                if hasTokenContent {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                    hasTokenContent = false
                }
                continue
            }

            current.append(character)
            hasTokenContent = true
        }

        if isEscaping {
            current.append("\\")
        }

        if quote != nil {
            throw DatabaseError.invalidConfiguration("Redis command contains an unterminated quoted string")
        }

        if hasTokenContent {
            tokens.append(current)
        }

        return tokens
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
        let response = try await send(RedisCommandParser.tokenize(sql))
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
        let args = try RedisCommandParser.tokenize(sql)
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
        let response = try await sendCommand(["MULTI"])
        guard case .simpleString(let value) = response, value.uppercased() == "OK" else {
            throw DatabaseError.transactionFailed("Redis failed to start transaction")
        }
        return RedisTransaction(connection: self)
    }

    public func close() async {
        connection.cancel()
        alive = false
    }

    public func isAlive() async -> Bool {
        alive
    }

    private func waitForReady(timeout: TimeInterval = 5) async throws {
        let readyState = RedisReadyState()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    readyState.resume(continuation, with: .success(()))
                case .failed(let error):
                    readyState.resume(continuation, with: .failure(DatabaseError.connectionFailed(error.localizedDescription)))
                case .cancelled:
                    readyState.resume(continuation, with: .failure(DatabaseError.connectionFailed("Redis connection was cancelled")))
                default:
                    break
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                readyState.resume(
                    continuation,
                    with: .failure(DatabaseError.connectionFailed("Redis connection timed out"))
                )
            }
        }
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

    func sendCommand(_ args: [String]) async throws -> RespValue {
        try await send(args)
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

        return try await receiveRESPValue()
    }

    private func receiveRESPValue() async throws -> RespValue {
        var buffer = Data()

        while true {
            let received = try await receiveChunk()
            buffer.append(received)

            if let value = try RedisRESPCodec.parseComplete(buffer) {
                return value
            }
        }
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: DatabaseError.queryFailed(error.localizedDescription))
                    return
                }

                guard let data, !data.isEmpty else {
                    if isComplete {
                        continuation.resume(throwing: DatabaseError.connectionFailed("Redis connection closed"))
                        return
                    }
                    continuation.resume(throwing: DatabaseError.queryFailed("空响应"))
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }
}

public final actor RedisTransaction: DatabaseTransaction {
    private let connection: RedisConnection
    private var completed = false

    init(connection: RedisConnection) {
        self.connection = connection
    }

    public func commit() async throws {
        guard !completed else {
            throw DatabaseError.transactionFailed("Transaction already completed")
        }

        let response = try await connection.sendCommand(["EXEC"])
        if case .error(let error) = response {
            throw DatabaseError.transactionFailed(error)
        }

        completed = true
    }

    public func rollback() async throws {
        guard !completed else {
            throw DatabaseError.transactionFailed("Transaction already completed")
        }

        let response = try await connection.sendCommand(["DISCARD"])
        guard case .simpleString(let value) = response, value.uppercased() == "OK" else {
            throw DatabaseError.transactionFailed("Redis failed to discard transaction")
        }

        completed = true
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard !completed else {
            throw DatabaseError.transactionFailed("Transaction already completed")
        }

        let response = try await connection.sendCommand(RedisCommandParser.tokenize(sql))
        switch response {
        case .simpleString(let value) where value.uppercased() == "QUEUED":
            return 0
        case .error(let error):
            throw DatabaseError.transactionFailed(error)
        default:
            throw DatabaseError.transactionFailed("Redis command was not queued")
        }
    }
}

private final class RedisReadyState: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(_ continuation: CheckedContinuation<Void, Error>, with result: Result<Void, Error>) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()

        switch result {
        case .success:
            continuation.resume(returning: ())
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
