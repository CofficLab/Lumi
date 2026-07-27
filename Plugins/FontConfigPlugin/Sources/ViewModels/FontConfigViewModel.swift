import SwiftUI
import AppKit
import Combine
import LumiKernel

/// 等宽字体数据项
public struct MonospacedFontItem: Identifiable, Equatable {
    public let postScriptName: String
    public let displayName: String

    public var id: String { postScriptName }
}

/// 字体配置 ViewModel
///
/// 负责扫描系统等宽字体、读写 EditorState.fontName、自管理持久化。
@MainActor
public final class FontConfigViewModel: ObservableObject {
    public static var applyFontNameHandler: (@MainActor (String?) -> Void)?

    /// 系统已安装的等宽字体列表
    @Published var availableFonts: [MonospacedFontItem] = []

    /// 当前选中的字体 PostScript Name，nil 表示系统默认
    @Published var selectedPostScriptName: String? {
        didSet {
            persist()
            applyToEditor()
        }
    }

    /// 当前字体显示名
    public var displayName: String {
        guard let psName = selectedPostScriptName else {
            return LumiPluginLocalization.string("System", bundle: .module)
        }
        return availableFonts.first { $0.postScriptName == psName }?.displayName ?? psName
    }

    // MARK: - Persistence

    private static let fontNameKey = "FontConfigPlugin.fontName"

    private func persist() {
        if let name = selectedPostScriptName {
            UserDefaults.standard.set(name, forKey: Self.fontNameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.fontNameKey)
        }
    }

    private func restore() {
        selectedPostScriptName = UserDefaults.standard.string(forKey: Self.fontNameKey)
    }

    // MARK: - Editor Sync

    /// 由视图 onAppear 调用，恢复字体配置并应用到宿主编辑器。
    public func start() {
        scanFonts()
        restore()
        applyToEditor()
    }

    /// 将当前选中的字体应用到 EditorState
    private func applyToEditor() {
        Self.applyFontNameHandler?(selectedPostScriptName)
    }

    /// 选择字体
    public func selectFont(_ postScriptName: String?) {
        selectedPostScriptName = postScriptName
    }

    // MARK: - Font Scanning

    /// 扫描系统中所有等宽字体
    private func scanFonts() {
        var fonts: [MonospacedFontItem] = []
        var seen = Set<String>()

        for font in NSFontManager.shared.availableFonts {
            // 跳过非等宽字体
            guard let nsFont = NSFont(name: font, size: 13),
                  nsFont.isFixedPitch else {
                continue
            }

            // 去重
            guard !seen.contains(font) else { continue }
            seen.insert(font)

            // 获取友好显示名
            let displayName = NSFontManager.shared.localizedName(forFamily: font, face: nil)

            fonts.append(MonospacedFontItem(
                postScriptName: font,
                displayName: displayName
            ))
        }

        // 按显示名排序
        fonts.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        availableFonts = fonts
    }
}
