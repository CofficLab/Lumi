import Foundation
import Network

/// RESP 协议值类型
enum RespValue: Equatable {
    case simpleString(String)
    case error(String)
    case integer(Int)
    case bulkString(Data?)
    case array([RespValue]?)
}

/// Redis 连接（Actor）
/// 通过 NWConnection 与 Redis 通信，提供基础命令执行能力以适配现有 DatabaseConnection 接口。
actor RedisConnection: DatabaseConnection {
    private let connection: NWConnection
    private var alive: Bool = false
    
    /// 初始化并建立连接
    /// - Parameters:
    ///   - host: Redis 主机
    ///   - port: Redis 端口（默认 6379）
    ///   - password: 可选密码，若提供则执行 AUTH
    init(host: String, port: Int = 6379, password: String? = nil) async throws {
        let params = NWParameters.tcp
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: params)
        
        let queue = DispatchQueue(label: "redis.connection.queue")
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // no-op
                break
            default:
                break
            }
        }
        connection.start(queue: queue)
        
        // 等待 ready
        try await waitForReady()
        alive = true
        
        // 认证与 PING
        if let pwd = password, !pwd.isEmpty {
            _ = try await send(["AUTH", pwd])
        }
        _ = try await send(["PING"])
    }
    
    /// 执行非查询命令（例如：SET、DEL）
    /// - Parameters:
    ///   - sql: 命令字符串（以空格分隔），例如 "SET key value"
    ///   - params: 暂不使用
    /// - Returns: 影响行数（仅用于兼容 UI，这里返回 1 表示成功）
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard alive else { throw DatabaseError.connectionFailed("Redis 连接未就绪") }
        let args = tokenize(sql)
        let resp = try await send(args)
        switch resp {
        case .simpleString(let s) where s.uppercased() == "OK":
            return 1
        case .integer(let i):
            return i
        case .bulkString(_), .array(_):
            return 1
        case .error(let e):
            throw DatabaseError.queryFailed(e)
        default:
            return 0
        }
    }
    
    /// 执行查询命令（支持 GET/SCAN 等）
    /// - Parameters:
    ///   - sql: 命令字符串，例如 "GET key" 或 "SCAN 0 MATCH * COUNT 50"
    ///   - params: 暂不使用
    /// - Returns: 结构化查询结果，用于表格展示
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        guard alive else { throw DatabaseError.connectionFailed("Redis 连接未就绪") }
        let args = tokenize(sql)
        let cmd = args.first?.uppercased() ?? ""
        let resp = try await send(args)
        
        switch cmd {
        case "GET":
            // 返回 Key/Value 两列
            let key = args.count > 1 ? args[1] : ""
            let valueString: String
            switch resp {
            case .bulkString(let data):
                if let d = data, let s = String(data: d, encoding: .utf8) {
                    valueString = s
                } else {
                    valueString = "NULL"
                }
            case .simpleString(let s):
                valueString = s
            case .integer(let i):
                valueString = String(i)
            case .error(let e):
                throw DatabaseError.queryFailed(e)
            default:
                valueString = "\(resp)"
            }
            return QueryResult(columns: ["Key", "Value"], rows: [[.string(key), .string(valueString)]], rowsAffected: 0)
            
        case "SCAN":
            // 解析返回值：*2 -> [cursor, [keys...]]
            var keys: [String] = []
            switch resp {
            case .array(let arrOpt):
                if let arr = arrOpt, arr.count >= 2 {
                    if case .array(let keysOpt) = arr[1], let keyVals = keysOpt {
                        keys = keyVals.compactMap { v in
                            if case .bulkString(let data) = v, let d = data, let s = String(data: d, encoding: .utf8) {
                                return s
                            }
                            return nil
                        }
                    }
                }
            default:
                break
            }
            let rows: [[DatabaseValue]] = keys.map { [DatabaseValue.string($0)] }
            return QueryResult(columns: ["Key"], rows: rows, rowsAffected: 0)
            
        default:
            // 通用结果展示
            switch resp {
            case .array(let arrOpt):
                let flat = flattenArray(arrOpt ?? [])
                let rows: [[DatabaseValue]] = flat.map { [DatabaseValue.string($0)] }
                return QueryResult(columns: ["Value"], rows: rows, rowsAffected: 0)
            case .bulkString(let data):
                let s = data.flatMap { String(data: $0, encoding: .utf8) } ?? "NULL"
                return QueryResult(columns: ["Value"], rows: [[.string(s)]], rowsAffected: 0)
            case .simpleString(let s):
                return QueryResult(columns: ["Value"], rows: [[.string(s)]], rowsAffected: 0)
            case .integer(let i):
                return QueryResult(columns: ["Value"], rows: [[.integer(i)]], rowsAffected: 0)
            case .error(let e):
                throw DatabaseError.queryFailed(e)
            }
        }
    }
    
    /// Redis 不提供传统事务接口，此处返回 notImplemented
    func beginTransaction() async throws -> DatabaseTransaction {
        throw DatabaseError.notImplemented
    }
    
    /// 关闭连接
    func close() async {
        connection.cancel()
        alive = false
    }
    
    /// 连接是否存活
    func isAlive() async -> Bool {
        return alive
    }
    
    // MARK: - 私有方法
    
    private func waitForReady() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    cont.resume(returning: ())
                case .failed(let err):
                    cont.resume(throwing: DatabaseError.connectionFailed(err.localizedDescription))
                default:
                    break
                }
            }
        }
    }
    
    private func tokenize(_ command: String) -> [String] {
        command.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }
    
    private func flattenArray(_ arr: [RespValue]) -> [String] {
        var out: [String] = []
        for v in arr {
            switch v {
            case .bulkString(let data):
                if let d = data, let s = String(data: d, encoding: .utf8) {
                    out.append(s)
                }
            case .simpleString(let s):
                out.append(s)
            case .integer(let i):
                out.append(String(i))
            case .array(let inner):
                out.append(contentsOf: flattenArray(inner ?? []))
            case .error(let e):
                out.append("ERR: \(e)")
            }
        }
        return out
    }
    
    private func send(_ args: [String]) async throws -> RespValue {
        let payload = encodeCommand(args)
        let data = payload.data(using: .utf8) ?? Data()
        
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed({ err in
                if let e = err {
                    cont.resume(throwing: DatabaseError.queryFailed(e.localizedDescription))
                } else {
                    cont.resume(returning: ())
                }
            }))
        }
        
        // 接收一次完整回复（简单实现，适用于短响应）
        let received = try await receiveOnce()
        return try parseRESP(received)
    }
    
    private func encodeCommand(_ args: [String]) -> String {
        var out = "*\(args.count)\r\n"
        for a in args {
            let utf8Count = a.data(using: .utf8)?.count ?? a.count
            out += "$\(utf8Count)\r\n"
            out += a
            out += "\r\n"
        }
        return out
    }
    
    private func receiveOnce() async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let e = error {
                    cont.resume(throwing: DatabaseError.queryFailed(e.localizedDescription))
                    return
                }
                guard let d = data else {
                    cont.resume(throwing: DatabaseError.queryFailed("空响应"))
                    return
                }
                cont.resume(returning: d)
            }
        }
    }
    
    private func parseRESP(_ data: Data) throws -> RespValue {
        guard let s = String(data: data, encoding: .utf8) else {
            return .bulkString(data)
        }
        var idx = s.startIndex
        func readLine() -> String? {
            guard let range = s[idx...].range(of: "\r\n") else { return nil }
            let line = String(s[idx..<range.lowerBound])
            idx = range.upperBound
            return line
        }
        func readBytes(_ count: Int) -> String? {
            let end = s.index(idx, offsetBy: count, limitedBy: s.endIndex) ?? s.endIndex
            let substr = String(s[idx..<end])
            idx = end
            // 跳过 CRLF
            _ = readLine()
            return substr
        }
        
        guard let prefix = s.first else { return .bulkString(data) }
        switch prefix {
        case "+":
            _ = readLine() // 去掉 '+'
            let line = readLine() ?? ""
            return .simpleString(line)
        case "-":
            _ = readLine()
            let line = readLine() ?? ""
            return .error(line)
        case ":":
            _ = readLine()
            let line = readLine() ?? "0"
            return .integer(Int(line) ?? 0)
        case "$":
            _ = readLine()
            let lenLine = readLine() ?? "-1"
            let len = Int(lenLine) ?? -1
            if len == -1 { return .bulkString(nil) }
            if let content = readBytes(len) {
                return .bulkString(content.data(using: .utf8))
            }
            return .bulkString(nil)
        case "*":
            _ = readLine()
            let countLine = readLine() ?? "0"
            let count = Int(countLine) ?? 0
            var items: [RespValue] = []
            for _ in 0..<count {
                // 递归解析子项（简化：重新切片数据，不做复杂流式解析）
                // 这里通过剩余字符串再次构造 Data 递归解析
                let remaining = String(s[idx...])
                let sub = try parseRESP(Data(remaining.utf8))
                items.append(sub)
                // 更新 idx：根据 remaining 的长度粗略推进，避免死循环
                // 简化处理：重新寻找新的起点
                // 为保证健壮性，遇到复杂嵌套时可能需要更完整的解析器，这里以能展示为主
                // 尝试跳到下一个元素的起点（查找第一个以 + - : $ * 开头的位置）
                if let nextIdx = remaining.firstIndex(where: { $0 == "+" || $0 == "-" || $0 == ":" || $0 == "$" || $0 == "*" }) {
                    idx = s.index(idx, offsetBy: remaining.distance(from: remaining.startIndex, to: nextIdx))
                } else {
                    idx = s.endIndex
                }
            }
            return .array(items)
        default:
            return .bulkString(data)
        }
    }
}
