#if canImport(MySQLNIO)
import Foundation
import NIOCore
import MySQLNIO
import Testing
@testable import DatabaseManagerPlugin

/// 回归 #585：SQL 结果集允许重复列名（`SELECT a.id, b.id`、多表 JOIN），
/// mysql-nio 的 `row.column(name)` 按名字返回首个匹配列，旧解码循环对每个
/// `columnDefinitions` 都调用它，导致后面的同名列错显首列的值，界面静默展示
/// 错误数据。修复改用 `columnDefinitions` 与 `values` 的位置对应逐列构造
/// `MySQLData`（`MySQLConnection.decodeRow`）。
///
/// `ColumnDefinition41` 的成员初始化器是 internal，无法跨模块直接构造；这里用
/// 其公开的 `decode(from:capabilities:)` 从手工拼装的协议包还原列定义，从而在
/// 不连真实 MySQL 的情况下构造带重复列名的 `MySQLRow`。
@Suite("MySQL Duplicate Column Decoding Tests")
struct MySQLDuplicateColumnDecodingTests {

    /// 按 ColumnDefinition41 协议布局拼装一个列定义包并解码。
    /// 6 个 lenenc_str（catalog/schema/table/orgTable/name/orgName）+ lenenc_int
    /// next_length(0x0c) + 12 字节定长尾（characterSet/collate/columnLength/
    /// columnType/flags/decimals/filler）。lenenc 辅助函数是 internal，故用公开
    /// 的 ByteBuffer API 手工写字节（长度 < 251 时 lenenc 即 1 字节长度 + 原文）。
    private func makeColumn(
        name: String,
        type: MySQLProtocol.DataType = .varchar,
        flags: MySQLProtocol.ColumnFlags = []
    ) throws -> MySQLProtocol.ColumnDefinition41 {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        for field in ["def", "testdb", "t", "t", name, name] {
            let bytes = Array(field.utf8)
            buffer.writeInteger(UInt8(bytes.count), endianness: .little)
            buffer.writeBytes(bytes)
        }
        buffer.writeInteger(UInt8(0x0c), endianness: .little)        // next_length
        buffer.writeInteger(UInt8(33), endianness: .little)          // characterSet utf8
        buffer.writeInteger(UInt8(0), endianness: .little)           // collate == 0
        buffer.writeInteger(UInt32(1024), endianness: .little)       // columnLength
        buffer.writeInteger(type.rawValue, endianness: .little, as: UInt8.self)
        buffer.writeInteger(flags.rawValue, endianness: .little, as: UInt16.self)
        buffer.writeInteger(UInt8(0), endianness: .little)           // decimals
        buffer.writeInteger(UInt16(0), endianness: .big)             // filler == 0
        var packet = MySQLPacket(payload: buffer)
        return try MySQLProtocol.ColumnDefinition41.decode(from: &packet, capabilities: [])
    }

    private func textBuffer(_ string: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }

    @Test("重复列名按位置保留各自的值，不得都显示首列")
    func duplicateColumnNamesKeepPositionalValues() throws {
        let row = MySQLRow(
            format: .text,
            columnDefinitions: [try makeColumn(name: "id"), try makeColumn(name: "id")],
            values: [textBuffer("1"), textBuffer("2")]
        )
        // 按名字解码会让两列都拿到首个 "id" 的 "1"；按位置应分别是 "1"、"2"。
        #expect(MySQLConnection.decodeRow(row) == [.string("1"), .string("2")])
    }

    @Test("JOIN 形态首尾同名列夹一个异名列，三列各按位置解码")
    func joinLikeDuplicateNamesAcrossThreeColumnsDecodeByPosition() throws {
        let row = MySQLRow(
            format: .text,
            columnDefinitions: [
                try makeColumn(name: "id"),
                try makeColumn(name: "name"),
                try makeColumn(name: "id"),
            ],
            values: [textBuffer("10"), textBuffer("alice"), textBuffer("20")]
        )
        #expect(MySQLConnection.decodeRow(row) == [.string("10"), .string("alice"), .string("20")])
    }

    @Test("重复列名中第二列为 NULL 时按位置解码为 null，不得回填首列值")
    func duplicateColumnNameWithNullSecondValueDecodesPositionally() throws {
        let row = MySQLRow(
            format: .text,
            columnDefinitions: [try makeColumn(name: "id"), try makeColumn(name: "id")],
            values: [textBuffer("1"), nil]
        )
        #expect(MySQLConnection.decodeRow(row) == [.string("1"), .null])
    }

    @Test("唯一列名仍按位置正确解码（重构不回归正常路径）")
    func uniqueColumnNamesStillDecodeCorrectly() throws {
        let row = MySQLRow(
            format: .text,
            columnDefinitions: [try makeColumn(name: "id"), try makeColumn(name: "name")],
            values: [textBuffer("1"), textBuffer("alice")]
        )
        #expect(MySQLConnection.decodeRow(row) == [.string("1"), .string("alice")])
    }
}
#endif