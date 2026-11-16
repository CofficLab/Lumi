import Foundation
import Testing
@testable import ComputerUsePlugin

/// 回归 #826：A3 自主会话的授权只存在于内存租约（`unattended`），不写入持久白名单。
/// 原生输入前的校验若仍要求持久白名单，第一个动作就会 `.stopped`，自主模式名存实亡。
/// 校验必须复用租约的 `approved` 语义；「停止」与系统权限收回仍能立即中断输入。
@MainActor
@Suite("原生控制租约授权 (#826)")
struct NativeControlApprovalTests {

    private func makeCoordinator() -> (NativeControlCoordinator, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseApproval-\(UUID().uuidString)", isDirectory: true)
        let coordinator = NativeControlCoordinator(
            authorization: ComputerUseAuthorizationStore(dataDirectory: directory),
            presentsUI: false
        )
        return (coordinator, directory)
    }

    @Test("自主租约即使持久白名单为空也必须被视为已授权（回归 #826）")
    func unattendedLeaseIsApprovedWithoutPersistedWhitelist() throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try coordinator.acquire(
            application: "Fixture", bundleID: "test.app", reason: "Test", unattended: true
        )

        #expect(coordinator.phase == .preparing)
        // 关键：持久白名单从未写入，但租约已授权——输入前校验不得再要求持久授权。
        #expect(coordinator.isApproved(session))
        coordinator.release(session)
    }

    @Test("有人值守租约在用户同意前不得被视为已授权")
    func attendedLeaseRequiresConsentBeforeApproval() throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try coordinator.acquire(
            application: "Fixture", bundleID: "test.app", reason: "Test"
        )

        #expect(coordinator.phase == .permission)
        #expect(!coordinator.isApproved(session))
        coordinator.allow()
        #expect(coordinator.isApproved(session))
        coordinator.release(session)
    }

    @Test("停止必须立即撤销租约授权（回归 #826）")
    func stopRevokesLeaseApproval() throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try coordinator.acquire(
            application: "Fixture", bundleID: "test.app", reason: "Test", unattended: true
        )
        #expect(coordinator.isApproved(session))

        coordinator.stop()
        #expect(!coordinator.isApproved(session))
        coordinator.release(session)
    }

    @Test("释放后的租约与外来会话都不得被视为已授权")
    func releasedOrForeignLeaseIsNotApproved() throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try coordinator.acquire(
            application: "Fixture", bundleID: "test.app", reason: "Test", unattended: true
        )
        #expect(!coordinator.isApproved(NativeControlSession()))

        coordinator.release(session)
        #expect(!coordinator.isApproved(session))
    }
}