import AppKit
import XCTest
@testable import LumiPreviewKit

/// 测试 `PreviewSurfaceCanvas` 包装的 `PreviewSurfaceView` 的行为。
///
/// 由于 `NSViewRepresentableContext` 无法在测试中直接创建，
/// 本测试套件直接测试 `PreviewSurfaceView`，它代表了 Canvas 的核心功能。
///
/// 覆盖以下场景：
/// 1. 视图创建和初始化
/// 2. surfaceID 绑定和解除
/// 3. 回调函数的设置
/// 4. 交互模式
@MainActor
final class PreviewSurfaceCanvasBehaviorTests: XCTestCase {

    // MARK: - Helper

    private func makeSurfaceView(
        frame: NSRect = NSRect(x: 0, y: 0, width: 320, height: 180),
        isInteractive: Bool = false
    ) -> LumiPreviewFacade.PreviewSurfaceView {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: frame)
        view.isInteractive = isInteractive
        return view
    }

    private func makeTestSurface(width: Int = 32, height: Int = 32, seq: UInt64 = 1) throws -> UInt32 {
        let frame = try XCTUnwrap(
            LumiPreviewFacade.DemoSurfaceFactory.makeFrame(
                width: width,
                height: height,
                scale: 1.0,
                seq: seq
            )
        )
        return frame.surfaceID
    }

    // MARK: - Initialization Tests

    func test_init_withDefaultFrame() {
        let view = makeSurfaceView()

        XCTAssertEqual(view.frame.width, 320)
        XCTAssertEqual(view.frame.height, 180)
        XCTAssertFalse(view.isInteractive)
        XCTAssertNil(view.currentSurfaceID)
    }

    func test_init_withCustomFrame() {
        let customFrame = NSRect(x: 10, y: 20, width: 800, height: 600)
        let view = makeSurfaceView(frame: customFrame)

        XCTAssertEqual(view.frame, customFrame)
    }

    func test_init_setsWantsLayer() {
        let view = makeSurfaceView()
        XCTAssertTrue(view.wantsLayer, "PreviewSurfaceView 应设置 wantsLayer = true")
    }

    // MARK: - Callback Tests

    func test_onSizeChange_callback_canBeSet() {
        let view = makeSurfaceView()
        var callbackCalled = false

        view.onSizeChange = { size, scale in
            callbackCalled = true
        }

        // 触发回调
        view.onSizeChange?(CGSize(width: 100, height: 100), 2.0)

        XCTAssertTrue(callbackCalled, "onSizeChange 回调应被调用")
    }

    func test_onInputEvent_callback_canBeSet() {
        let view = makeSurfaceView()
        var callbackCalled = false

        view.onInputEvent = { event in
            callbackCalled = true
        }

        // 触发回调
        let testEvent = LumiPreviewFacade.PreviewInputEvent.mouse(
            .init(phase: .down, button: .left, x: 0, y: 0, clickCount: 1, modifiers: [])
        )
        view.onInputEvent?(testEvent)

        XCTAssertTrue(callbackCalled, "onInputEvent 回调应被调用")
    }

    // MARK: - Interactive Mode Tests

    func test_isInteractive_defaultIsFalse() {
        let view = makeSurfaceView()
        XCTAssertFalse(view.isInteractive)
    }

    func test_isInteractive_canBeSetToTrue() {
        let view = makeSurfaceView(isInteractive: true)
        XCTAssertTrue(view.isInteractive)
    }

    func test_isInteractive_canBeToggled() {
        let view = makeSurfaceView()
        XCTAssertFalse(view.isInteractive)

        view.isInteractive = true
        XCTAssertTrue(view.isInteractive)

        view.isInteractive = false
        XCTAssertFalse(view.isInteractive)
    }

    // MARK: - Surface Attachment Tests

    func test_attachSurface_setsCurrentSurfaceID() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        XCTAssertNil(view.currentSurfaceID)

        view.attach(surfaceID: surfaceID)

        XCTAssertEqual(view.currentSurfaceID, surfaceID)
    }

    func test_attachSurface_setsLayerContents() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        view.attach(surfaceID: surfaceID)

        XCTAssertNil(view.layer?.contents, "root layer 不应直接承载 surface")
        XCTAssertNotEqual(view.debugContentLayerFrame, .zero, "content layer 应在 attach 后被设置")
    }

    func test_detachSurface_clearsCurrentSurfaceID() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        view.attach(surfaceID: surfaceID)
        view.detach()

        XCTAssertNil(view.currentSurfaceID, "detach 后 currentSurfaceID 应为 nil")
    }

    func test_detachSurface_clearsLayerContents() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        view.attach(surfaceID: surfaceID)
        view.detach()

        XCTAssertNil(view.layer?.contents, "detach 后 layer.contents 应为 nil")
        XCTAssertEqual(view.debugContentLayerFrame, .zero, "detach 后 content layer frame 应为空")
    }

    // MARK: - Swift 6 Regression Tests

    /// 回归测试：确保代码能通过 Swift 6 编译（隐式 self 捕获问题）
    func test_swift6_implicitSelfCapture_compiles() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        // 这些操作在 Swift 6 中需要显式的 self
        // 如果编译通过，说明问题已修复
        view.attach(surfaceID: surfaceID)
        view.layout()
        view.detach()

        XCTAssertNil(view.currentSurfaceID)
    }

    // MARK: - Edge Cases

    func test_attach_invalidSurfaceID_doesNotCrash() {
        let view = makeSurfaceView()
        view.attach(surfaceID: 0xFFFF_FFFF)
        // 不应崩溃，currentSurfaceID 应保持 nil
        XCTAssertNil(view.currentSurfaceID)
    }

    func test_attach_thenAttachAgain_updatesSurfaceID() throws {
        let view = makeSurfaceView()
        let surfaceID1 = try makeTestSurface(seq: 1)
        let surfaceID2 = try makeTestSurface(seq: 2)

        view.attach(surfaceID: surfaceID1)
        XCTAssertEqual(view.currentSurfaceID, surfaceID1)

        view.attach(surfaceID: surfaceID2)
        XCTAssertEqual(view.currentSurfaceID, surfaceID2, "应更新为新的 surfaceID")
    }

    func test_detach_withoutAttach_doesNotCrash() {
        let view = makeSurfaceView()
        view.detach()
        view.detach()
        // 不应崩溃
    }

    func test_multipleAttachDetachCycles() throws {
        let view = makeSurfaceView()

        for i in 1...5 {
            let surfaceID = try makeTestSurface(seq: UInt64(i))
            view.attach(surfaceID: surfaceID)
            XCTAssertEqual(view.currentSurfaceID, surfaceID)

            view.detach()
            XCTAssertNil(view.currentSurfaceID)
        }
    }
}
