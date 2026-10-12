# ProviderAgentRules

Lumi Agent Rule 的 Provider 契约。

插件通过 `AgentRuleContributing` 提供规则，并在 `onBoot` 中向内核解析到的
`AgentRuleProviding` 注册；插件关闭时按 `providerID` 撤回。规则内容不会被写入
项目 `.agent/rules` 目录，项目规则仍由 `PluginAgentRules` 从文件系统读取。
