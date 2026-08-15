import Foundation
import Testing

@testable import KernelLumi

/// 编辑器契约 V2 **值类型**契约测试（见重构方案 §21.1）。
///
/// 模块对应:`Sources/KernelLumi/Editor/Models/`。
@Suite("Editor Contract V2 Models")
struct EditorContractV2ModelTests {
    // MARK: - 标识

    @Test("强类型标识值语义与便捷构造")
    func identifiers() {
        let uuid = UUID()
        let a = EditorDocumentID(rawValue: uuid)
        let b = EditorDocumentID(rawValue: uuid)

        #expect(a == b)
        #expect(a != EditorDocumentID.makeUnique())
        #expect(EditorCommandID(rawValue: "editor.file.save").rawValue == "editor.file.save")

        // 不同标识类型即使 rawValue 相同也不应被混用比较(编译期由类型保证,
        // 这里验证它们是独立类型的事实源)。
        let session = EditorSessionID(rawValue: uuid)
        #expect(session.rawValue == a.rawValue)
        #expect(EditorWindowID.makeUnique() != EditorWindowID.makeUnique())
    }

    @Test("EditorScope 等值性")
    func scopeEquality() {
        let window = EditorWindowID.makeUnique()
        let workspace = EditorWorkspaceID.makeUnique()
        #expect(EditorScope(windowID: window, workspaceID: workspace) == EditorScope(windowID: window, workspaceID: workspace))
    }

    // MARK: - 位置与范围

    @Test("EditorPosition 可比较且 zero 原点")
    func positionOrdering() {
        #expect(EditorPosition.zero == EditorPosition(line: 0, character: 0))
        #expect(EditorPosition(line: 0, character: 3) < EditorPosition(line: 1, character: 0))
        #expect(EditorPosition(line: 2, character: 5) < EditorPosition(line: 2, character: 6))
    }

    @Test("EditorRange 规范化、重叠与包含")
    func rangeSemantics() {
        let range = EditorRange(start: EditorPosition(line: 1, character: 4), end: EditorPosition(line: 2, character: 0))
        #expect(range.isValid)

        // 反向范围 normalized 后有效。
        let reversed = EditorRange(start: range.end, end: range.start)
        #expect(reversed.isValid == false)
        #expect(reversed.normalized == range)

        // 相邻不算重叠。
        let adjacent = EditorRange(start: EditorPosition(line: 2, character: 0), end: EditorPosition(line: 3, character: 0))
        #expect(range.overlaps(adjacent) == false)

        // 交叉算重叠。
        let crossing = EditorRange(start: EditorPosition(line: 1, character: 6), end: EditorPosition(line: 2, character: 6))
        #expect(range.overlaps(crossing))

        // 空范围（插入点）与包含其起点的范围不算重叠。
        let point = EditorRange(at: range.start)
        #expect(range.overlaps(point) == false)

        #expect(range.contains(EditorPosition(line: 1, character: 4)))
        #expect(range.contains(EditorPosition(line: 1, character: 9)))
        #expect(range.contains(range.end) == false)
    }

    @Test("EditorLocation 持有 URI 与范围")
    func locationValue() {
        let url = URL(fileURLWithPath: "/tmp/a.swift")
        let location = EditorLocation(uri: url, range: EditorRange(at: .zero))
        #expect(location.uri == url)
        #expect(location.range.isEmpty)
    }

    // MARK: - 文档快照换算

    @Test("Snapshot LF 行的行列 ↔ UTF-16 偏移往返")
    func lfOffsetRoundTrip() throws {
        let text = "abc\ndefg\nhi"
        let snapshot = EditorDocumentSnapshot(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/a.txt"),
            languageID: "plaintext",
            revision: 1,
            text: text
        )

        #expect(snapshot.lineStartOffsets == [0, 4, 9])

        let p1 = EditorPosition(line: 1, character: 2)
        let offset = snapshot.offset(of: p1)
        #expect(offset == 6)
        #expect(snapshot.position(atOffset: 6) == p1)

        // 末行末尾（等于长度）合法。
        #expect(snapshot.position(atOffset: text.utf16.count) == EditorPosition(line: 2, character: 2))
        // 越界返回 nil。
        #expect(snapshot.offset(of: EditorPosition(line: 5, character: 0)) == nil)
        #expect(snapshot.offset(of: EditorPosition(line: 0, character: 99)) == nil)
        #expect(snapshot.position(atOffset: -1) == nil)
        #expect(snapshot.position(atOffset: text.utf16.count + 1) == nil)
    }

    @Test("Snapshot CRLF 行按双 code unit 分隔换算")
    func crlfOffsetRoundTrip() throws {
        let text = "ab\r\ncd"
        let snapshot = EditorDocumentSnapshot(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/a.txt"),
            languageID: "plaintext",
            revision: 1,
            text: text,
            lineEnding: .crlf
        )

        #expect(snapshot.lineStartOffsets == [0, 4])
        #expect(snapshot.offset(of: EditorPosition(line: 1, character: 1)) == 5)
        #expect(snapshot.position(atOffset: 4) == EditorPosition(line: 1, character: 0))
    }

    @Test("Snapshot BMP 外字符按 UTF-16 code unit 计数")
    func surrogatePairOffsets() throws {
        // "😀" 为 2 个 UTF-16 code unit。
        let text = "a😀b"
        let snapshot = EditorDocumentSnapshot(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/a.txt"),
            languageID: "plaintext",
            revision: 1,
            text: text
        )
        #expect(text.utf16.count == 4)
        // 'b' 的位置:line 0, character 3。
        #expect(snapshot.offset(of: EditorPosition(line: 0, character: 3)) == 3)
        #expect(snapshot.position(atOffset: 3) == EditorPosition(line: 0, character: 3))
    }

    @Test("Snapshot 摘要不携带完整文本")
    func summaryDropsText() {
        let snapshot = EditorDocumentSnapshot(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/a.txt"),
            languageID: "plaintext",
            revision: 7,
            text: "body",
            isDirty: true,
            largeFileMode: .degraded
        )
        let summary = snapshot.summary
        #expect(summary.id == snapshot.id)
        #expect(summary.revision == 7)
        #expect(summary.isDirty)
        #expect(summary.largeFileMode == .degraded)
    }

    // MARK: - 编辑事务

    @Test("DocumentEdit 检测重叠并给出确定性排序")
    func editOverlapAndOrdering() {
        let doc = EditorDocumentID.makeUnique()
        let e1 = EditorTextEdit(range: EditorRange(start: .init(line: 0, character: 0), end: .init(line: 0, character: 3)), newText: "x")
        let e2 = EditorTextEdit(range: EditorRange(start: .init(line: 0, character: 5), end: .init(line: 0, character: 8)), newText: "y")
        let e3 = EditorTextEdit(range: EditorRange(start: .init(line: 1, character: 0), end: .init(line: 1, character: 2)), newText: "z")

        let disjoint = EditorDocumentEdit(documentID: doc, edits: [e3, e1, e2])
        #expect(disjoint.hasOverlappingEdits == false)
        #expect(disjoint.sortedEdits.map(\.newText) == ["x", "y", "z"])

        let overlapping = EditorDocumentEdit(documentID: doc, edits: [e1, e2, EditorTextEdit(
            range: EditorRange(start: .init(line: 0, character: 7), end: .init(line: 0, character: 10)),
            newText: "w"
        )])
        #expect(overlapping.hasOverlappingEdits)
    }

    @Test("WorkspaceEdit 空判、重叠汇总与预览摘要")
    func workspaceEditSummary() {
        let docA = EditorDocumentID.makeUnique()
        let docB = EditorDocumentID.makeUnique()

        let empty = EditorWorkspaceEdit()
        #expect(empty.isEmpty)

        let edit = EditorWorkspaceEdit(
            documentEdits: [
                EditorDocumentEdit(documentID: docA, edits: [
                    EditorTextEdit(range: EditorRange(at: .zero), newText: "a"),
                ]),
                EditorDocumentEdit(documentID: docB, edits: [
                    EditorTextEdit(range: EditorRange(at: .zero), newText: "b"),
                    EditorTextEdit(range: EditorRange(start: .init(line: 1, character: 0), end: .init(line: 1, character: 1)), newText: "c"),
                ]),
            ],
            fileOperations: [EditorFileOperation(uri: URL(fileURLWithPath: "/tmp/old.swift"), kind: .rename(to: URL(fileURLWithPath: "/tmp/new.swift")))]
        )
        #expect(edit.isEmpty == false)
        #expect(edit.hasOverlappingEdits == false)
        #expect(edit.summaryDescription == "3 edits in 2 files, 1 file operation")
    }

    @Test("WorkspaceEditResult 部分失败判定")
    func editResult() {
        let doc = EditorDocumentID.makeUnique()
        let success = EditorWorkspaceEditResult(appliedDocumentIDs: [doc])
        #expect(success.isCompleteSuccess)

        let partial = EditorWorkspaceEditResult(
            appliedDocumentIDs: [doc],
            failures: [EditorDocumentID.makeUnique(): .revisionMismatch(documentID: EditorDocumentID.makeUnique(), expected: 1, actual: 2)]
        )
        #expect(partial.isCompleteSuccess == false)
    }

    // MARK: - 选择模型

    @Test("EditorSelection 范围规范化与多光标快照")
    func selectionSemantics() {
        let cursor = EditorSelection(at: EditorPosition(line: 3, character: 5))
        #expect(cursor.isEmpty)
        #expect(cursor.range == EditorRange(at: EditorPosition(line: 3, character: 5)))

        // 反向拖选:anchor 在后,active 在前。
        let reversed = EditorSelection(
            anchor: EditorPosition(line: 2, character: 8),
            active: EditorPosition(line: 2, character: 2)
        )
        #expect(reversed.isEmpty == false)
        #expect(reversed.range == EditorRange(
            start: EditorPosition(line: 2, character: 2),
            end: EditorPosition(line: 2, character: 8)
        ))

        let snapshot = EditorSelectionSnapshot(
            selections: [reversed, cursor],
            documentID: .makeUnique(),
            revision: 12
        )
        #expect(snapshot.primary == reversed)
        #expect(snapshot.revision == 12)
    }

    // MARK: - Workbench 状态

    @Test("Workbench 状态查询激活 group 与标签")
    func workbenchState() {
        let group1 = EditorGroupID.makeUnique()
        let group2 = EditorGroupID.makeUnique()
        let tabA = EditorSessionTab(id: .makeUnique(), documentID: .makeUnique(), title: "A")
        let tabB = EditorSessionTab(id: .makeUnique(), documentID: .makeUnique(), title: "B", isPinned: true)

        let state = EditorWorkbenchState(
            groups: [
                EditorGroupState(id: group1, tabs: [tabA, tabB], activeSessionID: tabB.id),
                EditorGroupState(id: group2, tabs: [], activeSessionID: nil),
            ],
            activeGroupID: group1
        )
        #expect(state.activeGroup?.id == group1)
        #expect(state.activeTab?.id == tabB.id)
        #expect(state.allTabs.count == 2)
    }

    // MARK: - 配置解析

    @Test("配置按 语言覆盖 > 工作区 > 用户 优先级解析")
    func configurationResolution() {
        let key = EditorSettingKey(rawValue: "editor.tabSize")
        let snapshot = EditorConfigurationSnapshot(
            userValues: [key: .int(4)],
            workspaceValues: [key: .int(2)],
            languageOverrides: ["swift": [key: .int(8)]]
        )
        #expect(snapshot.rawValue(for: key, context: EditorConfigurationContext(languageID: "swift")) == .int(8))
        #expect(snapshot.rawValue(for: key, context: EditorConfigurationContext(languageID: "go")) == .int(2))
        #expect(snapshot.rawValue(for: key, context: EditorConfigurationContext(languageID: nil)) == .int(2))
    }

    // MARK: - API 版本

    @Test("API 版本 major 兼容判定")
    func apiVersionCompatibility() {
        let host = EditorPluginAPIVersion(major: 2, minor: 5)
        #expect(EditorPluginAPIVersion(major: 2, minor: 0).isCompatible(with: host))
        #expect(EditorPluginAPIVersion(major: 2, minor: 5).isCompatible(with: host))
        // minor 高于宿主的 Bundle 拒绝安装。
        #expect(EditorPluginAPIVersion(major: 2, minor: 6).isCompatible(with: host) == false)
        #expect(EditorPluginAPIVersion(major: 1, minor: 9).isCompatible(with: host) == false)
        #expect(EditorPluginAPIVersion(major: 3, minor: 0).isCompatible(with: host) == false)
    }

    // MARK: - 错误模型

    @Test("契约错误可序列化描述且取消/超时为瞬时错误")
    func errorModel() {
        let mismatch = EditorContractError.revisionMismatch(documentID: .makeUnique(), expected: 3, actual: 4)
        #expect(mismatch.isTransient == false)
        #expect(mismatch.userDescription.isEmpty == false)

        #expect(EditorContractError.requestCancelled.isTransient)
        #expect(EditorContractError.requestTimedOut.isTransient)
        #expect(EditorContractError.workspaceNotTrusted.userDescription.isEmpty == false)
    }
}
