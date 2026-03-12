# Issue #10: 插件质量参差不齐

**严重程度**: 🟢 Low  
**状态**: Open  
**涉及文件**: `LumiApp/Plugins/`

---

## 问题描述

项目包含 43+ 个插件，但代码质量参差不齐，缺乏统一规范。

## 问题分析

### 1. 启用状态不一致
- 部分插件 `enable = true`
- 部分插件 `enable = false`
- 部分插件缺少明确的启用状态

### 2. 代码结构不一致
- 有的插件使用 `actor`
- 有的插件使用 `class`
- 初始化方式不统一

### 3. 缺少单元测试
- 大部分插件没有对应的测试文件
- 无法确保功能正确性

### 4. 冗余功能
- 存在功能重复的插件：
  - `AgentFileTreePlugin` vs `NativeFileTreePlugin` vs `AgentFileTreeNativePlugin`
  - `AgentMessagesPlugin` vs `AgentMessagesAppKitPlugin`

## 建议修复

1. **建立插件开发规范**
   - 统一的代码结构模板
   - 必需的协议实现
   - 错误处理规范

2. **审计现有插件**
   - 识别并合并重复功能
   - 移除未使用的插件
   - 补充单元测试

3. **添加插件质量检查**
   - CI 自动化检查
   - 代码审查清单

## 修复优先级

低 - 长期技术债务，但不影响现有功能