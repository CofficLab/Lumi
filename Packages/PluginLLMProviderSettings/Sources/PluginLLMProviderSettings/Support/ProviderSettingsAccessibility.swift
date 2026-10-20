import Foundation

/// 「云端供应商」设置页与「添加 / 编辑云端供应商」编辑器的无障碍标识符。
///
/// ## 为什么需要它
///
/// 设置页里的文案大量是插件内硬编码的中文字面量（如「添加供应商」），
/// 不走 `String(localized:)`，因此**不随 `-AppleLanguages` 变化**。
/// UI 测试若按文案定位，就会在中英文环境之间反复失效；
/// 按标识符定位则与语言无关。
///
/// ## 维护约定
///
/// - UI 测试 target 无法 import 插件模块，需在 `LumiUITests/LumiCloudProviderAddUITests.swift`
///   侧复述同一组常量，改动必须两边同步。
/// - 命名沿用 `lumi.<模块>.<元素>` 约定。
///
/// ## 不要给容器挂标识符
///
/// SwiftUI 会把容器上的 `accessibilityIdentifier` **继承给它的直接子元素**，
/// 并覆盖子元素自己的标识符。实测：给编辑器根 `VStack` 挂上标识符后，
/// 它的「取消 / 保存」按钮拿到的都是根标识符，而不是各自的
/// `…custom-provider.cancel` / `…custom-provider.save`——按后者定位永远找不到。
///
/// 因此这里的标识符**只挂在叶子控件上**，不给任何容器挂。
public enum ProviderSettingsAccessibility {
    /// 「添加供应商」按钮（仅云端供应商页显示）。
    public static let addProviderButton = "lumi.provider-settings.add-provider"
    /// 供应商数量标签（表头的「N 个云端供应商」）。
    ///
    /// - Important: 表头是 `Label(图标 + 文字)`，SwiftUI 不保证把它暴露成
    ///   `staticText`——实测在 macOS 上它落在别的元素类型上，
    ///   按 `staticTexts` 查询会一条都查不到。给它挂上标识符，
    ///   UI 测试才能稳定定位并读取其中的数量。
    public static let providerCountLabel = "lumi.provider-settings.provider-count"
    /// 侧边栏供应商搜索框。
    ///
    /// 新增的供应商排在列表末尾，而侧边栏是 `LazyVStack`——
    /// 末尾行在视口外时根本不会被物化，AX 树里压根找不到。
    /// UI 测试用搜索把列表过滤到只剩目标供应商，才能稳定定位到它。
    public static let searchField = "lumi.provider-settings.search"
    /// 供应商详情页的「编辑」按钮（仅自定义供应商显示）。
    public static let editProviderButton = "lumi.provider-settings.edit-provider"
    /// 供应商名称输入框。
    public static let nameField = "lumi.provider-settings.custom-provider.name"
    /// 描述输入框。
    public static let descriptionField = "lumi.provider-settings.custom-provider.description"
    /// 官网输入框。
    public static let websiteField = "lumi.provider-settings.custom-provider.website"
    /// API Endpoint URL 输入框。
    public static let baseURLField = "lumi.provider-settings.custom-provider.base-url"
    /// 模型 ID 多行输入框。
    public static let modelsField = "lumi.provider-settings.custom-provider.models"
    /// API 协议格式选择器。
    public static let apiFormatPicker = "lumi.provider-settings.custom-provider.api-format"
    /// 「保存」按钮。
    public static let saveButton = "lumi.provider-settings.custom-provider.save"
    /// 「取消」按钮。
    public static let cancelButton = "lumi.provider-settings.custom-provider.cancel"
    /// 保存失败时的错误横幅。
    public static let errorBanner = "lumi.provider-settings.custom-provider.error"
    /// 侧边栏供应商行。
    public static func providerRow(_ providerID: String) -> String {
        "lumi.provider-settings.provider.\(providerID)"
    }
}
