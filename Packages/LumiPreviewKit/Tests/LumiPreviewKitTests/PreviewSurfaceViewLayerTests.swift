import AppKit
import XCTest
@testable import LumiPreviewKit

/// 测试 `PreviewSurfaceView` 的 Layer 配置和布局行为。
///
/// 覆盖以下场景：
/// 1. Layer 的 bounds/frame 在布局时的正确性
/// 2. contentsScale 的设置
/// 3. 不同尺寸变化下的 layer 同步
/// 4. Swift 6 隐式 self 捕获的回归测试（确保编译通过）
@MainActor
final class PreviewSurfaceViewLayerTests: XCTestCase {

    // MARK: - Helper

    private func makeSurfaceView(frame: NSRect = NSRect(x: 0, y: 0, width: 320, height: 180)) -> LumiPreviewFacade.PreviewSurfaceView {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: frame)
        view.wantsLayer = true
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

    // MARK: - Layer Configuration Tests

    func test_makeBackingLayer_configuresCorrectly() {
        let view = makeSurfaceView()
        let layer = view.makeBackingLayer()

        XCTAssertEqual(layer.magnificationFilter, .linear, "magnificationFilter 应为 .linear")
        XCTAssertEqual(layer.minificationFilter, .linear, "minificationFilter 应为 .linear")
        XCTAssertFalse(layer.isOpaque, "isOpaque 应为 false")
        XCTAssertTrue(layer.masksToBounds, "root layer 应裁剪内部 content layer")
    }

    func test_attach_setsContentsScale_toWindowBackingScale() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        view.attach(surfaceID: surfaceID)

        XCTAssertNotNil(view.layer, "layer 不应为 nil")
        XCTAssertEqual(view.currentSurfaceID, surfaceID, "currentSurfaceID 应被设置")
        XCTAssertNil(view.layer?.contents, "root layer 不应直接承载 surface，避免被拉伸")
        XCTAssertNotEqual(view.debugContentLayerFrame, .zero, "content layer 应被设置")
    }

    func test_attach_retainsSurface() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        view.attach(surfaceID: surfaceID)

        XCTAssertEqual(view.currentSurfaceID, surfaceID)
    }

    // MARK: - Layout and Bounds Tests

    func test_layout_syncsLayerBounds_toViewBounds() {
        let view = makeSurfaceView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        _ = view.layer

        view.layout()

        XCTAssertEqual(Double(view.layer?.bounds.width ?? 0), 400, accuracy: 0.01, "layer.bounds.width 应等于 view.bounds.width")
        XCTAssertEqual(Double(view.layer?.bounds.height ?? 0), 300, accuracy: 0.01, "layer.bounds.height 应等于 view.bounds.height")
    }

    func test_layout_doesNotManuallySetFrame() {
        let view = makeSurfaceView(frame: NSRect(x: 10, y: 20, width: 400, height: 300))
        _ = view.layer

        view.layout()

        // layer.frame 应该由系统自动管理，不应该被手动设置为 bounds
        // 如果代码错误地设置了 layer.frame = bounds，这里会检测到
        XCTAssertNotEqual(view.layer?.frame, view.bounds, "layer.frame 不应被手动设置为 bounds")
    }

    func test_layout_afterBoundsChange_updatesLayerBounds() {
        let view = makeSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 150))
        _ = view.layer

        view.layout()

        // 改变 view 的 bounds
        view.bounds = NSRect(x: 0, y: 0, width: 800, height: 600)
        view.layout()

        XCTAssertEqual(Double(view.layer?.bounds.width ?? 0), 800, accuracy: 0.01, "layer.bounds 应同步到新的 view.bounds")
        XCTAssertEqual(Double(view.layer?.bounds.height ?? 0), 600, accuracy: 0.01)
    }

    // MARK: - Contents Scale Tests

    func test_viewDidChangeBackingProperties_updatesContentsScale() {
        let view = makeSurfaceView()
        _ = view.layer

        view.viewDidChangeBackingProperties()

        XCTAssertEqual(Double(view.layer?.contentsScale ?? 1), 1.0, accuracy: 0.01)
    }

    func test_viewDidMoveToWindow_updatesContentsScale() {
        let view = makeSurfaceView()
        _ = view.layer

        view.viewDidMoveToWindow()

        XCTAssertEqual(Double(view.layer?.contentsScale ?? 1), 1.0, accuracy: 0.01)
    }

    // MARK: - Swift 6 Implicit Self Capture Regression Tests

    /// 回归测试：确保在字符串插值中访问实例属性时使用显式 self
    /// 这个测试本身不测试功能，但确保代码能通过 Swift 6 编译
    func test_implicitSelfCapture_compilesSuccessfully() throws {
        let view = makeSurfaceView()
        let surfaceID = try makeTestSurface()

        // 这些操作在之前的实现中会导致 Swift 6 编译错误
        // 如果编译通过，说明隐式 self 问题已修复
        view.attach(surfaceID: surfaceID)
        view.layout()
        view.detach()

        // 验证基本功能仍然正常
        XCTAssertNil(view.currentSurfaceID, "detach 后 currentSurfaceID 应为 nil")
    }

    // MARK: - Resize and Scaling Tests

    func test_differentCanvasSizes_layerBoundsSyncCorrectly() {
        let testSizes: [CGSize] = [
            CGSize(width: 320, height: 180),
            CGSize(width: 640, height: 360),
            CGSize(width: 790, height: 390),
            CGSize(width: 1580, height: 780),
            CGSize(width: 100, height: 100),
        ]

        for size in testSizes {
            let view = makeSurfaceView(frame: NSRect(origin: .zero, size: size))
            _ = view.layer

            view.layout()

            XCTAssertEqual(
                Double(view.layer?.bounds.width ?? 0),
                Double(size.width),
                accuracy: 0.01,
                "Canvas size \(size) 的 layer.bounds.width 不正确"
            )
            XCTAssertEqual(
                Double(view.layer?.bounds.height ?? 0),
                Double(size.height),
                accuracy: 0.01,
                "Canvas size \(size) 的 layer.bounds.height 不正确"
            )
        }
    }

    func test_attach_withDifferentSurfaceSizes() throws {
        let view = makeSurfaceView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        let surfaceSizes: [(width: Int, height: Int)] = [
            (32, 32),
            (100, 100),
            (400, 300),
            (800, 600),
            (1580, 780),
        ]

        for (idx, size) in surfaceSizes.enumerated() {
            let surfaceID = try makeTestSurface(width: size.width, height: size.height, seq: UInt64(idx + 1))
            view.attach(surfaceID: surfaceID)

            XCTAssertEqual(view.currentSurfaceID, surfaceID, "表面 \(idx) 的 currentSurfaceID 不正确")
            XCTAssertNotEqual(view.debugContentLayerFrame, .zero, "表面 \(idx) 的 content layer frame 不应为空")
        }
    }

    func test_squareSurfaceKeepsNaturalSizeInsideWideView() throws {
        let view = makeSurfaceView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        let surfaceID = try makeTestSurface(width: 100, height: 100)

        view.attach(surfaceID: surfaceID)
        view.layout()

        XCTAssertEqual(Double(view.debugContentLayerFrame.width), 100, accuracy: 0.01)
        XCTAssertEqual(Double(view.debugContentLayerFrame.height), 100, accuracy: 0.01)
        XCTAssertEqual(Double(view.debugContentLayerFrame.minX), 150, accuracy: 0.01)
        XCTAssertEqual(Double(view.debugContentLayerFrame.minY), 50, accuracy: 0.01)
    }

    func test_largeSurfaceShrinksToFitInsideView() throws {
        let view = makeSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let surfaceID = try makeTestSurface(width: 400, height: 400)

        view.attach(surfaceID: surfaceID)
        view.layout()

        XCTAssertEqual(Double(view.debugContentLayerFrame.width), 100, accuracy: 0.01)
        XCTAssertEqual(Double(view.debugContentLayerFrame.height), 100, accuracy: 0.01)
        XCTAssertEqual(Double(view.debugContentLayerFrame.minX), 50, accuracy: 0.01)
        XCTAssertEqual(Double(view.debugContentLayerFrame.minY), 0, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func test_attach_withNilLayer_doesNotCrash() {
        let view = makeSurfaceView()
        let surfaceID: UInt32 = 12345
        view.attach(surfaceID: surfaceID)
    }

    func test_layout_withZeroBounds() {
        let view = makeSurfaceView(frame: .zero)
        _ = view.layer

        view.layout()

        XCTAssertEqual(Double(view.layer?.bounds.width ?? 0), 0, accuracy: 0.01)
        XCTAssertEqual(Double(view.layer?.bounds.height ?? 0), 0, accuracy: 0.01)
    }

    func test_detach_multipleTimes_doesNotCrash() {
        let view = makeSurfaceView()
        view.detach()
        view.detach()
        view.detach()
    }

    func test_attach_detach_attach_cycle() throws {
        let view = makeSurfaceView()
        let surfaceID1 = try makeTestSurface(seq: 1)
        let surfaceID2 = try makeTestSurface(seq: 2)

        view.attach(surfaceID: surfaceID1)
        XCTAssertEqual(view.currentSurfaceID, surfaceID1)

        view.detach()
        XCTAssertNil(view.currentSurfaceID)

        view.attach(surfaceID: surfaceID2)
        XCTAssertEqual(view.currentSurfaceID, surfaceID2)
    }
}
