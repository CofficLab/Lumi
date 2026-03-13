# Lumi 项目问题报告

**项目**: Lumi  
**更新时间**: 2026-03-13  
**分析范围**: 整个项目源码

---

## 问题统计

| 严重程度 | 数量 | 状态 |
|---------|------|------|
| 🔴 Critical | 4 | 待修复 |
| 🟠 High | 7 | 待修复 |
| 🟡 Medium | 6 | 待修复 |
| 🟢 Low | 0 | - |
| **总计** | **17** | - |

---

## 🔴 Critical 问题

| # | 标题 | 文件 | 文档 |
|---|------|------|------|
| 1 | Shell 命令风险评估存在安全漏洞 | CommandRiskEvaluator.swift | [issue-01](issue-01-shell-risk-evaluation.md) |
| 11 | LLMAPIService 详细日志泄露敏感信息 | LLMAPIService.swift | [issue-11](issue-11-verbose-logging-api-service.md) |
| 13 | API Key 明文存储风险 | LLMConfig 相关 | [issue-13](issue-13-apikey-plaintext-storage.md) |

---

## 🟠 High 问题

| # | 标题 | 文件 | 文档 |
|---|------|------|------|
| 2 | FinderSync 扩展删除操作无确认机制 | FinderSync+Actions.swift | [issue-02](issue-02-findersync-delete-confirmation.md) |
| 3 | 插件初始化中的 Task 创建风险 | 多个插件 | [issue-03](issue-03-plugin-task-initialization.md) |
| 4 | ShellTool 默认风险级别不正确 | ShellTool.swift | [issue-04](issue-04-shelltool-default-risk-level.md) |
| 5 | NetworkManagerPlugin 默认禁用 | NetworkManagerPlugin.swift | [issue-05](issue-05-network-manager-disabled.md) |
| 6 | 调试日志可能泄露敏感信息 | 多个文件 | [issue-06](issue-06-verbose-logging-security.md) |
| 12 | 缺少 API 请求速率限制 | LLMAPIService.swift | [issue-12](issue-12-api-rate-limiting.md) |
| 14 | 缺少 SSL/TLS 证书验证 | LLMAPIService.swift | [issue-14](issue-14-ssl-certificate-validation.md) |
| 15 | ConversationRuntimeStore 潜在内存泄漏 | ConversationRuntimeStore.swift | [issue-15](issue-15-memory-leak-runtime-store.md) |

---

## 🟡 Medium 问题

| # | 标题 | 文件 | 文档 |
|---|------|------|------|
| 7 | 缺少 LLMConfig 验证 | LLMConfig.swift | [issue-07](issue-07-llmconfig-validation.md) |
| 8 | ConversationRuntimeStore 清理不彻底 | ConversationRuntimeStore.swift | [issue-08](issue-08-runtime-store-cleanup.md) |
| 9 | 缺少错误处理和边界检查 | 多个文件 | [issue-09](issue-09-error-handling.md) |
| 10 | 插件质量参差不齐 | 多个插件 | [issue-10](issue-10-plugin-quality.md) |
| 16 | 缺少请求超时用户反馈 | LLMAPIService.swift, UI | [issue-16](issue-16-request-timeout-feedback.md) |
| 17 | 插件热重载可能导致状态不一致 | 插件系统 | [issue-17](issue-17-plugin-hot-reload.md) |

---

## 问题详情

### 安全相关问题 (Security)

#### Issue #1: Shell 命令风险评估存在安全漏洞 🔴

**问题描述**:
- 未处理管道符、重定向等命令组合
- 危险参数未检测
- chown 命令漏检
- 路径穿越风险

**建议修复**:
- 完善命令解析逻辑
- 增加危险参数模式匹配
- 实现完整的命令解析器

---

#### Issue #11: LLMAPIService 详细日志泄露敏感信息 🔴

**问题描述**:
- `verbose = true` 记录完整请求/响应
- API Key 可能出现在日志中
- 用户对话内容泄露

**建议修复**:
- 生产环境关闭详细日志
- 敏感信息脱敏处理
- 添加日志审计功能

---

#### Issue #13: API Key 明文存储风险 🔴

**问题描述**:
- API Key 可能明文存储在内存或配置文件中
- 内存转储可读取
- 崩溃日志可能包含

**建议修复**:
- 使用 Keychain 存储
- 内存中使用 SecureString
- 应用退出时清理敏感数据

---

#### Issue #14: 缺少 SSL/TLS 证书验证 🟠

**问题描述**:
- 未实现证书锁定
- 存在中间人攻击风险
- 公共 WiFi 环境风险

**建议修复**:
- 实现 SSL Pinning
- 验证服务器证书
- 处理证书更新

---

### 资源管理问题 (Resource Management)

#### Issue #15: ConversationRuntimeStore 潜在内存泄漏 🟠

**问题描述**:
- cleanupConversationState 可能遗漏状态
- Set 类型清理不完整
- @Published 属性频繁更新

**建议修复**:
- 完善清理方法
- 添加自动清理机制
- 实现内存监控

---

#### Issue #12: 缺少 API 请求速率限制 🟠

**问题描述**:
- 没有 RPM/TPM 限制
- 可能超配额
- 缺少用户提示

**建议修复**:
- 实现令牌桶算法
- 解析响应头更新限制
- UI 显示剩余配额

---

### 用户体验问题 (User Experience)

#### Issue #16: 缺少请求超时用户反馈 🟡

**问题描述**:
- 5 分钟超时无提示
- 用户不知道请求状态
- 缺少取消/重试选项

**建议修复**:
- 实时显示请求状态
- 超时警告机制
- 提供操作选项

---

### 代码质量问题 (Code Quality)

#### Issue #17: 插件热重载可能导致状态不一致 🟡

**问题描述**:
- 插件生命周期不完整
- 状态迁移机制缺失
- 依赖关系处理不当

**建议修复**:
- 定义完整生命周期
- 实现状态迁移
- 处理依赖关系

---

## 修复优先级建议

### 第一优先级 (P0) - 立即修复

1. **Issue #13**: API Key 明文存储风险
2. **Issue #11**: 日志泄露敏感信息
3. **Issue #1**: Shell 命令安全漏洞

### 第二优先级 (P1) - 本周修复

4. **Issue #14**: SSL 证书验证
5. **Issue #12**: API 速率限制
6. **Issue #15**: 内存泄漏

### 第三优先级 (P2) - 下周修复

7. **Issue #2-6**: 现有 High 级别问题
8. **Issue #16**: 用户体验改进

### 第四优先级 (P3) - 后续迭代

9. **Issue #7-10**: Medium 级别问题
10. **Issue #17**: 插件系统优化

---

## 检查清单

### 安全检查

- [ ] 所有敏感数据使用 Keychain 存储
- [ ] 生产环境关闭详细日志
- [ ] 实现 SSL 证书锁定
- [ ] 完善命令风险评估
- [ ] 添加输入验证

### 性能检查

- [ ] 检查内存泄漏
- [ ] 实现请求速率限制
- [ ] 优化大列表渲染
- [ ] 添加缓存机制

### 用户体验检查

- [ ] 添加加载状态指示
- [ ] 提供超时处理选项
- [ ] 优化错误提示
- [ ] 添加操作确认

### 代码质量检查

- [ ] 添加单元测试
- [ ] 完善文档注释
- [ ] 统一编码规范
- [ ] 代码审查

---

## 相关资源

- [改进建议总览](improvements-overview.md) - 功能改进建议
- [安全最佳实践](https://developer.apple.com/documentation/security)
- [Swift 并发指南](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

*本报告由 Lumi 自动分析生成*  
*最后更新: 2026-03-13*