import Combine
import SwiftUI

/// `DocsViewProviding` 的默认实现：持有「关于」与「说明书」条目数组。
///
/// 插件通过 `addAbout(_:)` / `addManual(_:)` 追加自己的文档条目；
/// 支持多插件各自贡献（与 `DefaultSettingViewProviding` 追加语义一致）。
@MainActor
public final class DefaultDocsViewProviding: DocsViewProviding, ObservableObject {
    @Published public private(set) var aboutEntries: [DocsEntry] = []
    @Published public private(set) var manualEntries: [DocsEntry] = []

    public init() {}

    public func replaceAboutEntries(_ entries: [DocsEntry]) {
        aboutEntries = entries
    }

    public func replaceManualEntries(_ entries: [DocsEntry]) {
        manualEntries = entries
    }
}
