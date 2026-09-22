import Foundation
import KitLocalization
import Testing
@testable import PluginMCP

@Suite("PluginMCP 本地化")
struct MCPLocalizationTests {
    /// LumiLocalization 优先按系统语言解析（Locale.preferredLanguages 优先于显式 locale），
    /// 测试环境为中文系统，故统一以 zh-Hans 断言命中结果。
    private func zh(_ key: String) -> String {
        LumiLocalization.string(key, bundle: Bundle.module, locale: Locale(identifier: "zh-Hans"))
    }

    @Test("xcstrings 中文翻译命中（简体）")
    func zhHansResolves() {
        #expect(zh("General") == "通用")
        #expect(zh("Enable MCP") == "启用 MCP")
        #expect(zh("Servers") == "服务器")
        #expect(zh("Add Server") == "添加服务器")
        #expect(zh("Save & Connect") == "保存并连接")
        #expect(zh("Security notice") == "安全提示")
    }

    @Test("连接状态文案走本地化 key（不再硬编码中文）")
    func connectionStateKeys() {
        #expect(MCPServerConnectionState.disconnected.displayName == "Disconnected")
        #expect(MCPServerConnectionState.connecting.displayName == "Connecting")
        #expect(MCPServerConnectionState.connected.displayName == "Running")
        #expect(MCPServerConnectionState.error("x").displayName == "Error")
        // 中文系统渲染路径应得到翻译。
        #expect(zh("Disconnected") == "已断开")
        #expect(zh("Connecting") == "连接中…")
        #expect(zh("Running") == "运行中")
        #expect(zh("Error") == "错误")
    }

    @Test("工具计数与风险等级文案翻译")
    func miscKeys() {
        #expect(zh("tools-count") == "%d 个工具")
        #expect(zh("Safe") == "安全")
        #expect(zh("Low") == "低风险")
        #expect(zh("Medium") == "中风险")
        #expect(zh("High") == "高风险")
        #expect(zh("Auto") == "自动")
    }
}
