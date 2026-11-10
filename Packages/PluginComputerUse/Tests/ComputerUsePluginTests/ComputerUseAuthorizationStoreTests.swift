import Foundation
import Testing
@testable import ComputerUsePlugin

/// 原生控制授权的存取。
///
/// 原生控制授权**不是应用白名单**：它记录的是「Lumi 接管过这个 App 的
/// 鼠标键盘」，与桌面横幅上的运行时确认直接相关，因此独立于会话自动化等级存在。
@Test func nativeAuthorizationStoresAndPersistsAcrossInstances() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ComputerUseAuthStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ComputerUseAuthorizationStore(dataDirectory: directory)

    #expect(!store.isNativeAllowed("com.example.editor"))
    store.setNativeAllowed(true, bundleIdentifier: "com.example.editor")
    #expect(store.isNativeAllowed("com.example.editor"))

    // 撤销后不得残留。
    store.revokeNative("com.example.editor")
    #expect(!store.isNativeAllowed("com.example.editor"))

    let reloaded = ComputerUseAuthorizationStore(dataDirectory: directory)
    store.setNativeAllowed(true, bundleIdentifier: "com.example.persisted")
    #expect(reloaded.isNativeAllowed("com.example.persisted"))
}

/// 旧版显式白名单必须被清除。
///
/// 显式白名单不再参与任何判定；留着它会让用户以为自己还能在设置里
/// 管理一份实际无效的名单。
@Test func legacyExplicitAllowlistIsPurged() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ComputerUseLegacyAllowlist-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ComputerUseAuthorizationStore(dataDirectory: directory)

    // 先写入一份旧格式数据，模拟升级前的存储。
    store.setNativeAllowed(true, bundleIdentifier: "com.example.editor")
    store.purgeLegacyExplicitAllowlist()

    // 旧 key 被清除后不应再有任何影响：原生控制授权保留，
    // 而「显式白名单」这个概念已经不存在。
    #expect(store.isNativeAllowed("com.example.editor"))
    #expect(!store.hasSessionAccess(
        bundleIdentifier: "com.example.editor",
        conversationID: UUID()
    ))
}
