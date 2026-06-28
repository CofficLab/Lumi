import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOSurface
import LumiPreviewKit
import SwiftUI

/// 子进程内的离屏 SwiftUI 渲染器。
///
/// 维护一个常驻的离屏 `NSWindow`（位置在 (-100000, -100000)），里面挂一个
/// `previewView`（默认是内置 `PreviewPlaceholderView` 的 `NSHostingView`，
/// 也可以通过 `loadDylib(path:symbolName:)` 替换为用户编译产出的 `NSView`）。
/// 每次 `snapshot()` 把当前画面写入一张 BGRA `IOSurface`，并返回 `IOSurfaceFrame`。
///
/// 通过 `kIOSurfaceIsGlobal: true` 让 surface ID 可被主进程 `IOSurfaceLookup`
/// 跨进程拿到。最近 `recentSurfaceLimit` 帧由本类强引用以避开 ARC 回收，
/// 给主进程留出消费时间窗口。
@MainActor
final class PreviewRenderer {

    // MARK: - 类型

    enum LoadDylibError: Error, CustomStringConvertible {
        case fileNotFound(String)
        case dlopenFailed(String)
        case symbolMissing(String)
        case viewSymbolReturnedNil
        case unexpectedReturnType

        var description: String {
            switch self {
            case let .fileNotFound(path):
                return "dylib not found at \(path)"
            case let .dlopenFailed(message):
                return "dlopen failed: \(message)"
            case let .symbolMissing(name):
                return "symbol \(name) missing in dylib"
            case .viewSymbolReturnedNil:
                return "view symbol returned nil"
            case .unexpectedReturnType:
                return "view symbol returned non-NSView object"
            }
        }
    }

    // MARK: - 属性

    private static let bgraPixelFormat: UInt32 =
        UInt32(UInt8(ascii: "B")) << 24 |
        UInt32(UInt8(ascii: "G")) << 16 |
        UInt32(UInt8(ascii: "R")) << 8 |
        UInt32(UInt8(ascii: "A"))

    private static let recentSurfaceLimit = 96
    private static let recentSurfaceByteBudget = 512 * 1024 * 1024
    private static let defaultPreviewCanvasSize = CGSize(width: 600, height: 900)

    /// 离屏窗口子类，强制 `canBecomeKey` / `canBecomeMain` 为 true。
    /// borderless 风格的 NSWindow 默认两者都为 false，会让 `sendEvent` 注入的
    /// keyDown 找不到 key window，TextField 等需要 firstResponder 的控件无法接键盘输入。
    ///
    /// 重写 `sendEvent` 以支持 SwiftUI 的 `.onHover`：
    /// 当收到 `mouseMoved` 事件时，手动触发 tracking area 的检查，
    /// 让 SwiftUI 的 `.onHover` 在离屏窗口中也能正常工作。
    final class InvisibleHostWindow: NSWindow {
        var syntheticMouseLocationInWindow: NSPoint?

        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }

        override var mouseLocationOutsideOfEventStream: NSPoint {
            syntheticMouseLocationInWindow ?? super.mouseLocationOutsideOfEventStream
        }

        override func sendEvent(_ event: NSEvent) {
            // 对于 mouseMoved 事件，手动触发 tracking area 检查
            // 让 SwiftUI 的 .onHover 能够正常工作
            if event.type == .mouseMoved {
                // 先让正常的事件分发进行
                super.sendEvent(event)

                // 然后手动触发 content view 的 tracking area 更新
                // 这会让 AppKit 检查所有 tracking area 并触发 mouseEntered/mouseExited
                contentView?.updateTrackingAreas()
            } else {
                super.sendEvent(event)
            }
        }
    }

    private var window: InvisibleHostWindow?
    private var previewView: NSView?
    private var loadedDylibHandle: UnsafeMutableRawPointer?
    private var debugStateProvider: (@MainActor () -> String?)?
    private struct RetainedSurface {
        let surface: IOSurfaceRef
        let byteCount: Int
    }

    private var recentSurfaces: [RetainedSurface] = []
    private var recentSurfaceBytes = 0
    private var seq: UInt64 = 0
    private var isDirty = true

    /// 暴露给 `PreviewEventDispatcher` 用于合成 `NSEvent.windowNumber` 与
    /// 调用 `sendEvent(_:)`。子进程内部使用，不跨进程。
    var hostWindow: NSWindow? { window }

    /// 当前离屏画布尺寸（点）。用户预览有明确 fitting size 时使用预览自身尺寸；
    /// 没有明确尺寸的弹性预览回退到固定 preview canvas，而不是外层面板尺寸。
    private(set) var pointSize: CGSize = CGSize(width: 320, height: 180)
    /// 主进程预览面板可用尺寸（点）。
    private var viewportSize: CGSize = CGSize(width: 320, height: 180)
    /// 用户预览没有明确 fitting/intrinsic size 时使用固定 canvas；
    /// 内置 placeholder/demo 仍使用外层 viewport，保持启动态行为。
    private var usesDefaultCanvasForUnconstrainedPreview = false
    /// 当前 backing scale。
    private(set) var scale: CGFloat = 2

    // MARK: - 初始化

    init() {
        ensureWindow()
        installDemoView()
    }

    // MARK: - 公开方法

    /// 调整离屏视图的逻辑尺寸与 backing scale。
    func resize(width: Int, height: Int, scale: CGFloat) {
        let pointWidth = max(1, CGFloat(width) / max(scale, 1))
        let pointHeight = max(1, CGFloat(height) / max(scale, 1))
        viewportSize = CGSize(width: pointWidth, height: pointHeight)
        self.scale = max(scale, 1)
        applyRenderSize()
        previewView?.needsLayout = true
        previewView?.needsDisplay = true
        markDirty()
    }

    /// 加载用户预览 dylib，并把其导出的 `NSView` 挂为当前 `previewView`。
    ///
    /// 符号约定：`@_cdecl(symbolName) func -> UnsafeMutableRawPointer?`，
    /// 返回 `Unmanaged.passRetained(view).toOpaque()`（+1 retained `NSView`）。
    func loadDylib(path: String, symbolName: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LoadDylibError.fileNotFound(path)
        }

        // 先卸载旧 dylib（句柄在 dlopen 成功后再切换，避免中间态）。
        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown"
            throw LoadDylibError.dlopenFailed(message)
        }

        guard let symbol = dlsym(handle, symbolName) else {
            dlclose(handle)
            throw LoadDylibError.symbolMissing(symbolName)
        }

        if try updateExistingPreviewIfPossible(with: handle) {
            replaceLoadedHandlePreservingView(with: handle)
            debugStateProvider = makeDebugStateProvider(handle: handle)
            return
        }

        typealias MakeViewFn = @convention(c) () -> UnsafeMutableRawPointer?
        let makeView = unsafeBitCast(symbol, to: MakeViewFn.self)
        guard let opaque = makeView() else {
            dlclose(handle)
            throw LoadDylibError.viewSymbolReturnedNil
        }

        let unmanaged = Unmanaged<AnyObject>.fromOpaque(opaque)
        let object = unmanaged.takeRetainedValue()
        guard let view = object as? NSView else {
            // 让旧句柄保留一帧再 dlclose，避免对象析构访问 dylib 已映射段时 crash。
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                dlclose(handle)
            }
            throw LoadDylibError.unexpectedReturnType
        }

        unloadDylib()  // 卸老
        loadedDylibHandle = handle
        debugStateProvider = makeDebugStateProvider(handle: handle)
        usesDefaultCanvasForUnconstrainedPreview = true
        installView(view)
    }

    /// 卸载当前用户 dylib，恢复内置空白视图。
    func unloadDylib() {
        installDemoView()
        debugStateProvider = nil
        if let handle = loadedDylibHandle {
            // 推迟一拍 dlclose：先让旧 view 的析构完成，避免它引用 dylib 中已 unmap 的代码段。
            loadedDylibHandle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                dlclose(handle)
            }
        }
    }

    /// 读取用户 entry 可选导出的调试状态。
    func entryDebugState() -> String? {
        debugStateProvider?()
    }

    /// 输入注入前确保离屏窗口仍处于可接收键盘事件的 responder 状态。
    func prepareForInputDispatch() {
        ensureWindow()
        guard let window else { return }
        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }
        if window.firstResponder == nil, let previewView {
            window.makeFirstResponder(previewView)
        }
    }

    /// 让离屏窗口用主进程转发过来的鼠标位置参与 AppKit/SwiftUI hover tracking。
    func setSyntheticMouseLocation(_ location: NSPoint?) {
        window?.syntheticMouseLocationInWindow = location
    }

    func markDirty() {
        isDirty = true
    }

    func snapshotIfDirty() -> LumiPreviewFacade.IOSurfaceFrame? {
        guard isDirty else { return nil }
        guard let frame = snapshot() else { return nil }
        isDirty = false
        return frame
    }

    /// 抓一张当前画面到 IOSurface，返回跨进程帧描述符。
    func snapshot() -> LumiPreviewFacade.IOSurfaceFrame? {
        guard let view = previewView else { return nil }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        let pointBounds = view.bounds
        guard pointBounds.width > 0, pointBounds.height > 0 else { return nil }

        let pixelWidth = max(1, Int((pointBounds.width * scale).rounded()))
        let pixelHeight = max(1, Int((pointBounds.height * scale).rounded()))
        let bytesPerRow = pixelWidth * 4

        guard let surface = makeSurface(width: pixelWidth, height: pixelHeight, bytesPerRow: bytesPerRow) else {
            return nil
        }

        var seed: UInt32 = 0
        guard IOSurfaceLock(surface, [], &seed) == KERN_SUCCESS else { return nil }
        defer { _ = IOSurfaceUnlock(surface, [], &seed) }

        guard let baseAddress = IOSurfaceGetBaseAddressOfPlane(surface, 0) as UnsafeMutableRawPointer?,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: baseAddress,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        context.interpolationQuality = .high

        // Snapshot 走 NSBitmapImageRep（layer-backed view 的可靠路径）。
        // 离屏窗口可能拿不到真实 Retina backing，显式按 pointSize × scale 创建位图。
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: bytesPerRow,
            bitsPerPixel: 32
        ) else { return nil }
        bitmap.size = pointBounds.size
        view.cacheDisplay(in: pointBounds, to: bitmap)
        guard let cgImage = bitmap.cgImage else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        retain(surface, byteCount: bytesPerRow * pixelHeight)
        seq &+= 1

        return LumiPreviewFacade.IOSurfaceFrame(
            surfaceID: UInt32(IOSurfaceGetID(surface)),
            width: pixelWidth,
            height: pixelHeight,
            scale: Double(scale),
            seq: seq
        )
    }

    // MARK: - 私有方法

    private func ensureWindow() {
        guard window == nil else { return }
        let frame = NSRect(origin: .zero, size: pointSize)
        let window = InvisibleHostWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        // 不再 ignoresMouseEvents：sendEvent 注入需要 window 接收事件分发。
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isOpaque = false
        window.setFrameOrigin(NSPoint(x: -100_000, y: -100_000))
        window.orderFrontRegardless()
        // makeKey 让 keyDown 注入时能找到 key window；窗口在屏幕外不影响主屏幕用户。
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func installDemoView() {
        let hosting = NSHostingView(rootView: AnyView(PreviewPlaceholderView()))
        usesDefaultCanvasForUnconstrainedPreview = false
        installView(hosting)
    }

    private func installView(_ view: NSView) {
        guard let window else { return }
        pointSize = resolvedRenderSize(for: view)
        let frame = NSRect(origin: .zero, size: pointSize)
        view.frame = frame
        view.wantsLayer = true
        window.contentView = view
        window.setContentSize(frame.size)
        previewView = view
        view.needsLayout = true
        view.needsDisplay = true
        markDirty()
        // 让 hosting view 成为 firstResponder：键盘事件能直达 SwiftUI TextField。
        // NSHostingView 通过 _NSResponderChain 内部转发到具体控件。
        window.makeFirstResponder(view)
    }

    private func applyRenderSize() {
        guard let previewView else { return }
        pointSize = resolvedRenderSize(for: previewView)
        let frame = NSRect(origin: .zero, size: pointSize)
        previewView.frame = frame
        window?.setContentSize(frame.size)
    }

    private func resolvedRenderSize(for view: NSView) -> CGSize {
        guard usesDefaultCanvasForUnconstrainedPreview else {
            return viewportSize
        }

        let preferred = view.fittingSize
        if isUsablePreferredSize(preferred) {
            return preferred
        }
        let intrinsic = view.intrinsicContentSize
        if isUsablePreferredSize(intrinsic) {
            return intrinsic
        }
        return Self.defaultPreviewCanvasSize
    }

    private func isUsablePreferredSize(_ size: CGSize) -> Bool {
        size.width.isFinite &&
        size.height.isFinite &&
        size.width > 1 &&
        size.height > 1 &&
        size.width != NSView.noIntrinsicMetric &&
        size.height != NSView.noIntrinsicMetric
    }

    private func updateExistingPreviewIfPossible(with handle: UnsafeMutableRawPointer) throws -> Bool {
        guard let previewView,
              let updateSymbol = dlsym(handle, "lumi_preview_update_nsview") else {
            return false
        }
        typealias UpdateViewFn = @convention(c) (UnsafeMutableRawPointer?) -> Bool
        let updateView = unsafeBitCast(updateSymbol, to: UpdateViewFn.self)
        let updated = updateView(Unmanaged.passUnretained(previewView).toOpaque())
        guard updated else { return false }
        usesDefaultCanvasForUnconstrainedPreview = true
        applyRenderSize()
        previewView.wantsLayer = true
        previewView.needsLayout = true
        previewView.needsDisplay = true
        window?.setContentSize(pointSize)
        markDirty()
        prepareForInputDispatch()
        return true
    }

    private func replaceLoadedHandlePreservingView(with handle: UnsafeMutableRawPointer) {
        if let oldHandle = loadedDylibHandle {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                dlclose(oldHandle)
            }
        }
        loadedDylibHandle = handle
    }

    private func makeDebugStateProvider(handle: UnsafeMutableRawPointer) -> (@MainActor () -> String?)? {
        guard let symbol = dlsym(handle, "lumi_preview_debug_state") else { return nil }
        typealias DebugStateFn = @convention(c) () -> UnsafeMutableRawPointer?
        let debugState = unsafeBitCast(symbol, to: DebugStateFn.self)
        return {
            guard let opaque = debugState() else { return nil }
            let unmanaged = Unmanaged<AnyObject>.fromOpaque(opaque)
            let object = unmanaged.takeRetainedValue()
            if let string = object as? String {
                return string
            }
            if let string = object as? NSString {
                return string as String
            }
            return nil
        }
    }

    private func makeSurface(width: Int, height: Int, bytesPerRow: Int) -> IOSurfaceRef? {
        let properties: [CFString: Any] = [
            kIOSurfaceWidth: width,
            kIOSurfaceHeight: height,
            kIOSurfaceBytesPerElement: 4,
            kIOSurfaceBytesPerRow: bytesPerRow,
            kIOSurfacePixelFormat: Self.bgraPixelFormat,
            // 跨进程共享：消费端通过 IOSurfaceLookup(surfaceID) 按 ID 取回 surface，
            // 这要求 surface 必须是 global。kIOSurfaceIsGlobal 被标记为 deprecated
            //（"Global surfaces are insecure"），但当前架构依赖 ID 跨进程序列化，
            // 故此处有意保留该用法。迁移到 mach port 传递可彻底消除该警告。
            kIOSurfaceIsGlobal: true
        ]
        return IOSurfaceCreate(properties as CFDictionary)
    }

    private func retain(_ surface: IOSurfaceRef, byteCount: Int) {
        recentSurfaces.append(RetainedSurface(surface: surface, byteCount: byteCount))
        recentSurfaceBytes += byteCount

        while recentSurfaces.count > 1 &&
              (recentSurfaces.count > Self.recentSurfaceLimit ||
               recentSurfaceBytes > Self.recentSurfaceByteBudget) {
            let removed = recentSurfaces.removeFirst()
            recentSurfaceBytes -= removed.byteCount
        }
    }

    private func diagnostic(_ message: String) {
        fputs("[PreviewRenderer] \(message)\n", stderr)
        fflush(stderr)
    }

    private func describe(_ view: NSView?) -> String {
        guard let view else { return "nil" }
        return "\(String(describing: type(of: view))) frame=\(format(view.frame.size)) bounds=\(format(view.bounds.size)) hidden=\(view.isHidden) alpha=\(format(view.alphaValue)) layer=\(view.layer != nil)"
    }

    private func describe(_ window: NSWindow?) -> String {
        guard let window else { return "nil" }
        return "frame=\(format(window.frame.size)) content=\(format(window.contentView?.bounds.size ?? .zero)) visible=\(window.isVisible) key=\(window.isKeyWindow)"
    }

    private func format(_ size: CGSize) -> String {
        "\(String(format: "%.1f", size.width))x\(String(format: "%.1f", size.height))"
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }
}
