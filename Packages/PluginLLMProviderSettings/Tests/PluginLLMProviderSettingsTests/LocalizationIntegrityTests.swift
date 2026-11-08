import Foundation
import Testing
@testable import PluginLLMProviderSettings

/// 供应商设置页的英文文案契约。
///
/// 这些 key 都会直接上屏（包含 `AppSettingSection` / `AppSettingRow` /
/// `AppButton` 等只接受 String 的组件），所以缺 en 时英文界面会退化成
/// 中文 key。单测无法渲染 SwiftUI 文案，只能读 xcstrings 本身兜底。
@Suite("本地化资源完整性")
struct LocalizationIntegrityTests {
    /// #880 报告及本轮修复过的全部用户可见 key。
    private static let userFacingKeys = [
        "API 密钥",
        "配置访问凭证",
        "输入 API Key",
        "操作",
        "尚未保存 API Key",
        "已保存 API Key",
        "隐藏 API Key",
        "显示 API Key",
        "复制 API Key",
        "已复制",
        "保存",
        "删除",
        "错误",
        "可用模型",
        "上下文 %@",
        "视觉",
        "当前",
        "编辑",
        "删除自定义供应商？",
        "这会移除供应商配置和对应的 API Key。",
        "访问官网",
        "取消",
        "%lld 个模型",
        "%lld 个本地供应商",
        "%lld 个云端供应商",
        "添加供应商",
        "未找到供应商",
        "选择一个供应商",
        "搜索供应商",
        "添加云端供应商",
        "编辑云端供应商",
        "配置兼容的 API 端点和模型列表",
        "基本信息",
        "供应商名称",
        "描述（可选）",
        "官网（可选）",
        "连接",
        "模型",
        "模型 ID（每行一个）",
        "OpenAI 兼容",
        "Anthropic 兼容",
        "模型下载",
        "缓存占用",
        "下载限速",
        "打开",
        "不限速",
        "自定义",
        "正在下载...",
        "已暂停",
        "已下载",
        "暂停下载",
        "继续下载",
        "取消下载",
        "下载",
    ]

    @Test("供应商设置页的可见文案都有 en 翻译")
    func userFacingKeysIncludeEnglish() throws {
        let catalog = try Self.loadCatalog()

        for key in Self.userFacingKeys {
            let entry = try #require(
                catalog[key],
                "「\(key)」未出现在 xcstrings 中，但代码里已作为可见文案使用"
            )
            let english = try #require(
                entry["en"],
                "「\(key)」缺少 en 翻译，英文界面会把 key 直接显示出来"
            )
            #expect(!english.isEmpty, "「\(key)」的 en 翻译为空")
            #expect(
                english != key,
                "「\(key)」的 en 翻译仍是中文原文，英文界面不会生效"
            )
        }
    }

    // MARK: - Helpers

    private static func loadCatalog() throws -> [String: [String: String]] {
        let url = try #require(
            catalogURL(),
            "找不到本包的 xcstrings 资源文件"
        )
        let data = try Data(contentsOf: url)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "xcstrings 根节点不是 JSON 对象"
        )
        let strings = try #require(root["strings"] as? [String: Any], "xcstrings 缺少 strings 节点")

        var result: [String: [String: String]] = [:]
        for (key, value) in strings {
            guard let value = value as? [String: Any],
                  let raw = value["localizations"] as? [String: Any] else {
                result[key] = [:]
                continue
            }
            var localizations: [String: String] = [:]
            for (language, unit) in raw {
                guard let unit = unit as? [String: Any],
                      let stringUnit = unit["stringUnit"] as? [String: Any],
                      let text = stringUnit["value"] as? String else { continue }
                localizations[language] = text
            }
            result[key] = localizations
        }
        return result
    }

    /// 从包目录定位 xcstrings（测试运行时的当前目录不可依赖）。
    private static func catalogURL() -> URL? {
        var directory = URL(fileURLWithPath: #filePath)
        // Tests/PluginLLMProviderSettingsTests/<file> → 包根
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        let url = directory
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
