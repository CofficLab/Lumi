import Foundation
import Testing
@testable import EditorKernel

/// 回归 #397：`EditorExternalFileController.shouldReloadForChange` 此前只在
/// **非 dirty** 时才比较磁盘修改时间，dirty 时无条件返回 true。于是只要编辑器有
/// 未保存修改，下一次 watcher 轮询就把「本地缓冲区与磁盘不同」误判为「磁盘被外部
/// 修改」，弹出外部冲突并阻断自动保存——即便磁盘的内容与修改时间根本没变。
///
/// 是否外部改动只取决于磁盘修改时间相对上次已知值是否真的变化，与本地是否 dirty
/// 无关；真正的冲突判定交给 `EditorExternalFileReloadPolicy.reloadDecision` 的内容比较。
@Suite("EditorExternalFileConflict")
@MainActor
struct EditorExternalFileConflictTests {

    @Test("纯本地 dirty 且磁盘未变，不得误报为外部改动")
    func purelyLocalDirtyEditIsNotAnExternalConflict() {
        let controller = EditorExternalFileController()
        let modDate = Date()
        controller.recordUnchangedModificationDate(modDate)

        // 磁盘修改时间未变（容差 0.5s 内），无论是否 dirty 都不应触发重载/冲突。
        #expect(controller.shouldReloadForChange(currentModDate: modDate, hasUnsavedChanges: true) == false)
        #expect(controller.shouldReloadForChange(currentModDate: modDate.addingTimeInterval(0.2), hasUnsavedChanges: true) == false)
        #expect(controller.shouldReloadForChange(currentModDate: modDate.addingTimeInterval(0.2), hasUnsavedChanges: false) == false)
    }

    @Test("磁盘真的被外部修改时，无论是否 dirty 都必须检出", arguments: [true, false])
    func realExternalChangeIsDetectedRegardlessOfDirtyState(hasUnsavedChanges: Bool) {
        let controller = EditorExternalFileController()
        let modDate = Date()
        controller.recordUnchangedModificationDate(modDate)

        // 修改时间前进超过容差，说明确有外部改动，dirty 与否都要进入重载判定。
        #expect(controller.shouldReloadForChange(currentModDate: modDate.addingTimeInterval(1.0), hasUnsavedChanges: hasUnsavedChanges) == true)
    }

    @Test("尚无已知修改时间时保守地允许重载")
    func unknownBaselineReloadsConservatively() {
        let controller = EditorExternalFileController()
        let modDate = Date()

        // 未记录基线（lastKnownModificationDate 为 nil）时无法判断是否变化，保守返回 true。
        #expect(controller.shouldReloadForChange(currentModDate: modDate, hasUnsavedChanges: true) == true)
        #expect(controller.shouldReloadForChange(currentModDate: modDate, hasUnsavedChanges: false) == true)
    }
}