import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOSurface
import LumiInlinePreviewKit
import SwiftUI

/// 子进程内的离屏 SwiftUI 渲染器。
///
/// 维护一个常驻的离屏 `NSWindow`（位置在 (-100000, -100000)），里面挂一个
/// `previewView`（默认是内置 `HotPreviewPlaceholderView` 的 `NSHostingView`，
/// 也可以通过 `loadDylib(path:symbolName:)` 替换为用户编译产出的 `NSView`）。
/// 每次 `snapshot()` 把当前画面写入一张 BGRA `IOSurface`，并返回 `IOSurfaceFrame`。
///
/// 通过 `kIOSurfaceIsGlobal: true` 让 surface ID 可被主进程 `IOSurfaceLookup`
/// 跨进程拿到。最近 `recentSurfaceLimit` 帧由本类强引用以避开 ARC 回收，
/// 给主进程留出消费时间窗口。
@MainActor
final class HotPreviewRenderer {

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

    private static let recentSurfaceLimit = 8

    /// 离屏窗口子类，强制 `canBecomeKey` / `canBecomeMain` 为 true。
    /// borderless 风格的 NSWindow 默认两者都为 false，会让 `sendEvent` 注入的
    /// keyDown 找不到 key window，TextField 等需要 firstResponder 的控件无法接键盘输入。
    final class InvisibleHostWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    private var window: InvisibleHostWindow?
    private var previewView: NSView?
    private var loadedDylibHandle: UnsafeMutableRawPointer?
    private var recentSurfaces: [IOSurfaceRef] = []
    private var seq: UInt64 = 0

    /// 暴露给 `HotPreviewEventDispatcher` 用于合成 `NSEvent.windowNumber` 与
    /// 调用 `sendEvent(_:)`。子进程内部使用，不跨进程。
    var hostWindow: NSWindow? { window }

    /// 当前承载的视图尺寸（点）。
    private(set) var pointSize: CGSize = CGSize(width: 320, height: 180)
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
        pointSize = CGSize(width: pointWidth, height: pointHeight)
        self.scale = max(scale, 1)
        let frame = NSRect(x: 0, y: 0, width: pointWidth, height: pointHeight)
        previewView?.frame = frame
        window?.setContentSize(frame.size)
        previewView?.needsLayout = true
        previewView?.needsDisplay = true
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
        installView(view)
    }

    /// 卸载当前用户 dylib，恢复内置空白视图。
    func unloadDylib() {
        installDemoView()
        if let handle = loadedDylibHandle {
            // 推迟一拍 dlclose：先让旧 view 的析构完成，避免它引用 dylib 中已 unmap 的代码段。
            loadedDylibHandle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                dlclose(handle)
            }
        }
    }

    /// 抓一张当前画面到 IOSurface，返回跨进程帧描述符。
    func snapshot() -> LumiInlinePreviewFacade.IOSurfaceFrame? {
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

        // Snapshot 走 NSBitmapImageRep（layer-backed view 的可靠路径）。
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: pointBounds) else { return nil }
        bitmap.size = pointBounds.size
        view.cacheDisplay(in: pointBounds, to: bitmap)
        guard let cgImage = bitmap.cgImage else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        retain(surface)
        seq &+= 1

        return LumiInlinePreviewFacade.IOSurfaceFrame(
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
        let hosting = NSHostingView(rootView: AnyView(HotPreviewPlaceholderView()))
        installView(hosting)
    }

    private func installView(_ view: NSView) {
        guard let window else { return }
        let frame = NSRect(origin: .zero, size: pointSize)
        view.frame = frame
        view.wantsLayer = true
        window.contentView = view
        window.setContentSize(frame.size)
        previewView = view
        view.needsLayout = true
        view.needsDisplay = true
        // 让 hosting view 成为 firstResponder：键盘事件能直达 SwiftUI TextField。
        // NSHostingView 通过 _NSResponderChain 内部转发到具体控件。
        window.makeFirstResponder(view)
    }

    private func makeSurface(width: Int, height: Int, bytesPerRow: Int) -> IOSurfaceRef? {
        let properties: [CFString: Any] = [
            kIOSurfaceWidth: width,
            kIOSurfaceHeight: height,
            kIOSurfaceBytesPerElement: 4,
            kIOSurfaceBytesPerRow: bytesPerRow,
            kIOSurfacePixelFormat: Self.bgraPixelFormat,
            kIOSurfaceIsGlobal: true
        ]
        return IOSurfaceCreate(properties as CFDictionary)
    }

    private func retain(_ surface: IOSurfaceRef) {
        recentSurfaces.append(surface)
        if recentSurfaces.count > Self.recentSurfaceLimit {
            recentSurfaces.removeFirst(recentSurfaces.count - Self.recentSurfaceLimit)
        }
    }
}
