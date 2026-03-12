# Issue #4: ShellTool 默认风险级别不正确

**严重程度**: 🟠 High  
**状态**: Open  
**文件**: `LumiApp/Plugins/AgentCoreToolsPlugin/Tools/ShellTool.swift`

---

## 问题描述

`ShellTool` 的 `permissionRiskLevel` 方法在无法解析命令参数时，默认返回 `.medium` 风险级别，而不是更安全的 `.high`。

## 当前代码

```swift
func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
    guard let command = arguments["command"]?.value as? String else {
        return .medium  // 问题：应该返回 .high
    }
    return CommandRiskEvaluator.evaluate(command: command)
}
```

## 问题分析

1. **安全原则**: 对于无法识别/解析的命令，应该假定为高风险
2. **最小权限原则**: 默认拒绝未知命令比默认允许更安全
3. **参数解析失败**: 当 command 参数缺失或类型错误时，应视为危险信号

## 建议修复

```swift
func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
    guard let command = arguments["command"]?.value as? String else {
        return .high  // 修复：无法解析时默认为高风险
    }
    return CommandRiskEvaluator.evaluate(command: command)
}
```

## 修复优先级

中 - 间接增加了命令注入风险