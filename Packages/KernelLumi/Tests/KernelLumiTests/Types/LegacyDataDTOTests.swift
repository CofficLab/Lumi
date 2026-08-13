import Foundation
import Testing
@testable import KernelLumi

/// legacy 迁移相关**值类型**测试(纯数据,与内核注册/协议无关)。
///
/// 模块对应:`Sources/KernelLumi/Types/Data/LumiLegacyData.swift`。
/// Provider 契约测试见 `Providers/LegacyDataProvidingTests.swift`。
@Suite("Legacy Data Types")
struct LegacyDataDTOTests {
    // MARK: - Error

    @Test("LegacyDataError 各 case 有非空 errorDescription")
    func errorDescriptions() throws {
        let underlying = NSError(domain: "test", code: 42)

        #expect((LegacyDataError.legacyDataNotFound.errorDescription ?? "").isEmpty == false)
        #expect((LegacyDataError.snapshotCopyFailed(underlying: underlying).errorDescription ?? "").isEmpty == false)
        #expect((LegacyDataError.openFailed(underlying: underlying).errorDescription ?? "").isEmpty == false)
        #expect((LegacyDataError.fetchFailed(entity: "Conversation", underlying: underlying).errorDescription ?? "").isEmpty == false)
    }

    @Test("LegacyDataError 符合 Error,可被 do/catch 捕获")
    func errorIsThrowable() throws {
        #expect(throws: LegacyDataError.self) {
            throw LegacyDataError.legacyDataNotFound
        }
    }

    // MARK: - DTO

    @Test("LumiLegacyDataSnapshot 持有源路径与副本路径")
    func snapshotValueSemantics() throws {
        let source = URL(fileURLWithPath: "/db_production_v4")
        let snapshot = URL(fileURLWithPath: "/tmp/snapshot")
        let value = LumiLegacyDataSnapshot(snapshotURL: snapshot, sourceURL: source)
        #expect(value.snapshotURL == snapshot)
        #expect(value.sourceURL == source)
    }

    @Test("LumiLegacyDataKind 枚举值")
    func migrationKinds() throws {
        #expect(LumiLegacyDataKind.conversations.rawValue == "conversations")
        #expect(LumiLegacyDataKind.messages.rawValue == "messages")
    }
}
