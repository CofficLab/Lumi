import SwiftUI

// MARK: - 主题切换器（用于预览和设置）
///
/// 管理应用主题的 ObservableObject，支持主题切换和持久化
///
@MainActor
class ThemeManager: ObservableObject {
    /// 当前选中的主题变体，修改时自动保存并更新全局主题
    @Published var currentVariant: Themes.Variant {
        didSet {
            // 更新全局主题
            Themes.currentVariant = currentVariant
            // 保存用户选择
            currentVariant.save()
            // 触发更新
            updateColors()
        }
    }

    /// 是否启用高对比度模式
    @Published var isHighContrast: Bool = false {
        didSet {
            Themes.isHighContrast = isHighContrast
        }
    }

    /// 初始化主题管理器，加载保存的主题
    init() {
        // 从 UserDefaults 加载保存的主题
        self.currentVariant = Themes.Variant.loadSaved()
        // 应用加载的主题
        Themes.currentVariant = currentVariant
    }

    private func updateColors() {
        // 更新主题时会自动刷新
        objectWillChange.send()
    }
}

// MARK: - 预览
#Preview("主题管理器") {
    Text("MystiqueThemeManager 单文件预览")
        .mystiqueBackground()
        .environmentObject(ThemeManager())
}
