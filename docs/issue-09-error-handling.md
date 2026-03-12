# Issue #9: 缺少错误处理和边界检查

**严重程度**: 🟡 Medium  
**状态**: Open  
**涉及文件**: 
- `LumiApp/Plugins/AgentCoreToolsPlugin/Tools/ShellTool.swift`
- `LumiFinder/FinderSync+Actions.swift`
- 多处代码

---

## 问题描述

多处代码缺少健壮的错误处理和边界检查，可能导致应用崩溃或异常行为。

## 问题分析

### 1. ShellTool.execute - 错误被吞没

```swift
func execute(arguments: [String: ToolArgument]) async throws -> String {
    guard let command = arguments["command"]?.value as? String else {
        throw NSError(/* ... */)
    }

    let riskLevel = CommandRiskEvaluator.evaluate(command: command)
    // ...
    
    do {
        let output = try await shellService.execute(command)
        return output
    } catch {
        // 问题：返回错误字符串而非抛出异常，隐藏真实错误
        return "Error executing command: \(error.localizedDescription)"
    }
}
```

问题：
- 捕获异常后返回错误字符串，调用者无法区分成功和失败
- 错误信息可能泄露系统细节
- 破坏了 async/throw 的错误传播机制

### 2. FinderSync - 缺少边界检查

多处操作未检查数组边界：
- `cachedTemplates[index]` 未验证 index 有效性
- `getSelectedURLs()` 返回 nil 时未处理

### 3. 缺少空值检查

多处使用 `!` 强制解包可能导致崩溃：
- `arguments["command"]?.value as? String` 后直接使用
- 可选类型未正确处理

## 建议修复

### ShellTool 改进
```swift
func execute(arguments: [String: ToolArgument]) async throws -> String {
    guard let command = arguments["command"]?.value as? String else {
        throw ShellToolError.missingCommand
    }

    do {
        let output = try await shellService.execute(command)
        return output
    } catch let error as ShellToolError {
        throw error
    } catch {
        // 记录日志但重新抛出原始错误
        os_log("Shell execution failed: \(error.localizedDescription)")
        throw ShellToolError.executionFailed(underlying: error)
    }
}

enum ShellToolError: Error {
    case missingCommand
    case executionFailed(underlying: Error)
    // ...
}
```

### 添加边界检查
```swift
guard index >= 0, index < cachedTemplates.count else {
    os_log("Invalid template index: \(index)")
    return
}
```

## 修复优先级

中 - 影响应用稳定性和可维护性