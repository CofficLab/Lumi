import Foundation

/// `ToastProviding` 的默认 no-op 实现。
///
/// 骨架阶段使用：不展示任何 UI，静默丢弃（满足协议「非阻塞、不抛错」契约）。
/// 需要真实展示的宿主应提供自己的 UI 实现替换（如根覆盖层渲染）。
@MainActor
public final class DefaultToastProviding: ToastProviding {
    public init() {}

    public func show(_ toast: LumiToast) {
        // no-op：骨架阶段不渲染，静默丢弃。
    }
}
