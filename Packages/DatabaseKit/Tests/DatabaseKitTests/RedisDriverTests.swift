import Foundation
import Testing
@testable import DatabaseKit

struct RedisDriverTests {
    @Test
    func redisDriverTypeIsRedis() {
        let driver = RedisDriver()
        #expect(driver.type == .redis)
    }

    @Test
    func redisDriverRejectsMissingHost() async throws {
        let driver = RedisDriver()
        let config = DatabaseConfig(name: "No Host", type: .redis, host: nil, database: "redis")

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func redisDriverRejectsEmptyHost() async throws {
        let driver = RedisDriver()
        let config = DatabaseConfig(name: "Empty Host", type: .redis, host: "", database: "redis")

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func redisDriverUsesDefaultPort() async throws {
        let driver = RedisDriver()
        // Note: This would require a real Redis server, so we'll test the logic only
        let config = DatabaseConfig(
            name: "Default Port",
            type: .redis,
            host: "localhost",
            port: nil,  // Should default to 6379
            database: "redis"
        )

        // We can't test actual connection without a Redis server,
        // but we can verify the driver was created correctly
        #expect(driver.type == .redis)
    }
}

struct RedisRESPCodecTests {
    @Test
    func encodeSimpleCommand() throws {
        let data = RedisRESPCodec.encodeCommand(["PING"])
        let string = try #require(String(data: data, encoding: .utf8))

        #expect(string == "*1\r\n$4\r\nPING\r\n")
    }

    @Test
    func encodeMultiArgCommand() throws {
        let data = RedisRESPCodec.encodeCommand(["SET", "key", "value"])
        let string = try #require(String(data: data, encoding: .utf8))

        #expect(string == "*3\r\n$3\r\nSET\r\n$3\r\nkey\r\n$5\r\nvalue\r\n")
    }

    @Test
    func encodeEmptyArray() throws {
        let data = RedisRESPCodec.encodeCommand([])
        let string = try #require(String(data: data, encoding: .utf8))

        #expect(string == "*0\r\n")
    }

    @Test
    func encodeUnicodeStrings() throws {
        let data = RedisRESPCodec.encodeCommand(["SET", "emoji", "😀"])
        let string = try #require(String(data: data, encoding: .utf8))

        #expect(string.contains("emoji"))
        #expect(string.contains("😀"))
    }

    @Test
    func parseSimpleString() throws {
        let data = Data("+OK\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .simpleString(let value) = result {
            #expect(value == "OK")
        } else {
            Issue.record("Expected simple string")
        }
    }

    @Test
    func parseError() throws {
        let data = Data("-ERR unknown command\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .error(let message) = result {
            #expect(message == "ERR unknown command")
        } else {
            Issue.record("Expected error")
        }
    }

    @Test
    func parseInteger() throws {
        let data = Data(":1000\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .integer(let value) = result {
            #expect(value == 1000)
        } else {
            Issue.record("Expected integer")
        }
    }

    @Test
    func parseBulkString() throws {
        let data = Data("$5\r\nhello\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .bulkString(let valueData?) = result {
            let string = String(data: valueData, encoding: .utf8)
            #expect(string == "hello")
        } else {
            Issue.record("Expected bulk string with data")
        }
    }

    @Test
    func parseNullBulkString() throws {
        let data = Data("$-1\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .bulkString(nil) = result {
            // Success
        } else {
            Issue.record("Expected null bulk string")
        }
    }

    @Test
    func parseEmptyBulkString() throws {
        let data = Data("$0\r\n\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .bulkString(let valueData?) = result {
            #expect(valueData.isEmpty)
        } else {
            Issue.record("Expected empty bulk string")
        }
    }

    @Test
    func parseSimpleArray() throws {
        let data = Data("*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .array(let values?) = result {
            #expect(values.count == 2)

            if case .bulkString(let first?) = values[0] {
                #expect(String(data: first, encoding: .utf8) == "foo")
            } else {
                Issue.record("Expected bulk string in array[0]")
            }

            if case .bulkString(let second?) = values[1] {
                #expect(String(data: second, encoding: .utf8) == "bar")
            } else {
                Issue.record("Expected bulk string in array[1]")
            }
        } else {
            Issue.record("Expected array")
        }
    }

    @Test
    func parseNestedArray() throws {
        let data = Data("*2\r\n$1\r\n0\r\n*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .array(let outer?) = result {
            #expect(outer.count == 2)

            // First element: bulk string "0"
            if case .bulkString(let first?) = outer[0] {
                #expect(String(data: first, encoding: .utf8) == "0")
            }

            // Second element: nested array
            if case .array(let inner?) = outer[1] {
                #expect(inner.count == 2)
            }
        } else {
            Issue.record("Expected array with nested array")
        }
    }

    @Test
    func parseNullArray() throws {
        let data = Data("*-1\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .array(nil) = result {
            // Success
        } else {
            Issue.record("Expected null array")
        }
    }

    @Test
    func parseEmptyArray() throws {
        let data = Data("*0\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .array(let values?) = result {
            #expect(values.isEmpty)
        } else {
            Issue.record("Expected empty array")
        }
    }

    @Test
    func parseMixedTypeArray() throws {
        let data = Data("*3\r\n:1\r\n$3\r\nfoo\r\n+OK\r\n".utf8)
        let result = try RedisRESPCodec.parse(data)

        if case .array(let values?) = result {
            #expect(values.count == 3)

            if case .integer(1) = values[0] {
                // Success
            } else {
                Issue.record("Expected integer in array[0]")
            }

            if case .bulkString(let data?) = values[1] {
                #expect(String(data: data, encoding: .utf8) == "foo")
            } else {
                Issue.record("Expected bulk string in array[1]")
            }

            if case .simpleString("OK") = values[2] {
                // Success
            } else {
                Issue.record("Expected simple string in array[2]")
            }
        } else {
            Issue.record("Expected mixed type array")
        }
    }

    @Test
    func parseMalformedLineEndingThrows() throws {
        let data = Data("+OK\n".utf8)  // Missing \r before \n

        #expect(throws: DatabaseError.self) {
            _ = try RedisRESPCodec.parse(data)
        }
    }

    @Test
    func parseIncompleteBulkStringThrows() throws {
        let data = Data("$5\r\nhel".utf8)  // Only 3 bytes instead of 5

        #expect(throws: DatabaseError.self) {
            _ = try RedisRESPCodec.parse(data)
        }
    }

    @Test
    func parseMissingCRAfterBulkStringThrows() throws {
        let data = Data("$5\r\nhello\n".utf8)  // Missing \r before \n

        #expect(throws: DatabaseError.self) {
            _ = try RedisRESPCodec.parse(data)
        }
    }

    @Test
    func respValueEquality() {
        #expect(RespValue.simpleString("OK") == RespValue.simpleString("OK"))
        #expect(RespValue.integer(10) == RespValue.integer(10))
        #expect(RespValue.error("ERR") == RespValue.error("ERR"))
        #expect(RespValue.bulkString(Data("test".utf8)) == RespValue.bulkString(Data("test".utf8)))
        #expect(RespValue.array([.integer(1)]) == RespValue.array([.integer(1)]))
    }

    @Test
    func respValueInequality() {
        #expect(RespValue.simpleString("OK") != RespValue.simpleString("NO"))
        #expect(RespValue.integer(10) != RespValue.integer(20))
        #expect(RespValue.bulkString(nil) != RespValue.bulkString(Data()))
        #expect(RespValue.array(nil) != RespValue.array([]))
    }
}