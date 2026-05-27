# App Store Connect API 研究报告

## 概述

App Store Connect API 是苹果官方提供的 REST API，用于自动化开发者在 Apple Developer 网站和 App Store Connect 中执行的任务。该 API 允许开发者以编程方式管理应用、测试、分发、报告等所有相关操作，实现高效的 App 上架和管理工作流。

**官方文档**：[https://developer.apple.com/documentation/appstoreconnectapi](https://developer.apple.com/documentation/appstoreconnectapi)

## 核心特性

- **RESTful 架构**：标准的 REST API，返回 JSON 格式数据
- **JWT 授权**：使用 JSON Web Tokens (JWT) 进行身份验证
- **全面的自动化能力**：覆盖 App Store Connect 的几乎所有手动操作
- **实时数据同步**：直接操作生产数据，影响线上状态

## 主要功能领域

根据官方文档，App Store Connect API 提供以下核心功能：

### 1. 应用内购买与订阅管理
- 管理应用内购买项目
- 配置自动续订订阅
- 管理订阅组和价格

### 2. TestFlight 测试分发
- 管理预发布版本和测试构建
- 管理测试员和测试组
- 配置测试飞行相关设置

### 3. Xcode Cloud 集成
- 读取 Xcode Cloud 数据
- 管理工作流配置
- 启动构建任务

### 4. 用户与访问控制
- 发送团队邀请
- 调整用户访问权限
- 移除团队成员

### 5. 配置文件管理
- 管理 Bundle IDs
- 配置应用能力
- 管理签名证书
- 注册测试设备
- 创建和下载配置文件

### 6. 应用元数据管理
- 创建新版本
- 管理 App Store 信息
- 提交应用审核
- **编辑应用信息**
- **编辑宣传图和截图**

### 7. App Clip 体验
- 创建 App Clip
- 管理 App Clip 体验配置

### 8. 报告与分析
- 下载销售和财务报告
- 获取应用使用数据
- 获取性能指标和诊断信息

### 9. 客户评价管理
- 获取应用评价
- 管理评价回复

## 认证与授权

### API 密钥创建
需要在 App Store Connect 中创建 API 密钥：
1. 登录 App Store Connect
2. 导航到用户和访问 > 密钥
3. 创建新的 API 密钥
4. 下载并保存私钥文件（.p8 格式）

### JWT 令牌生成
使用私钥生成 JWT 令牌进行 API 请求授权。令牌包含：
- **Issuer ID**：团队 ID
- **Key ID**：API 密钥 ID
- **私钥**：用于签名

### 速率限制
API 有速率限制，需要正确处理响应中的限制信息。

## 与 Lumi 插件相关的 API 端点

### 应用管理
- `GET /v1/apps`：获取所有应用列表
- `GET /v1/apps/{id}`：获取单个应用详情
- `PATCH /v1/apps/{id}`：更新应用信息
- `POST /v1/apps`：创建新应用

### 应用版本管理
- `GET /v1/apps/{id}/appStoreVersions`：获取应用版本
- `POST /v1/appStoreVersions`：创建新版本
- `PATCH /v1/appStoreVersions/{id}`：更新版本信息

### 本地化信息
- `GET /v1/appStoreVersionLocalizations`：获取版本本地化
- `POST /v1/appStoreVersionLocalizations`：创建本地化
- `PATCH /v1/appStoreVersionLocalizations/{id}`：更新本地化信息

### 宣传图和截图
- `GET /v1/appStoreVersionScreenshots`：获取截图列表
- `POST /v1/appStoreVersionScreenshots`：上传新截图
- `DELETE /v1/appStoreVersionScreenshots/{id}`：删除截图

### 应用图标
- `GET /v1/appIcons`：获取应用图标
- `POST /v1/appIcons`：上传新图标

### 审核提交
- `POST /v1/appStoreVersionSubmissions`：提交审核
- `POST /v1/appReviewSubmissions`：创建审核提交

## 技术要求

### 基础设施
- **HTTPS**：所有请求必须使用 HTTPS
- **JSON**：请求和响应使用 JSON 格式
- **分页**：支持大量数据的分页获取

### 错误处理
API 返回标准 HTTP 状态码和详细的错误信息，需要正确处理各种错误场景。

## 开发集成建议

### 1. 认证模块
实现 JWT 令牌生成和刷新机制

### 2. API 客户端
创建 REST API 客户端封装所有端点调用

### 3. 文件上传
实现大文件上传（截图、图标等）的支持

### 4. 错误处理
统一的错误处理和重试机制

### 5. 本地化支持
支持多语言应用信息的编辑

## 安全考虑

1. **私钥安全**：安全存储 API 私钥，避免泄露
2. **令牌管理**：合理管理 JWT 令牌的生命周期
3. **权限最小化**：仅请求必要的 API 权限
4. **审计日志**：记录所有 API 操作

## 限制与注意事项

1. **生产影响**：API 操作直接影响生产数据
2. **速率限制**：需要遵守 API 调用频率限制
3. **网络延迟**：文件上传等操作可能需要较长时间
4. **审核时间**：应用提交后需要苹果审核时间

## 相关资源

- [OpenAPI 规范文件](https://developer.apple.com/documentation/appstoreconnectapi/openapi_specification)：下载完整的 API 规范
- [API 版本说明](https://developer.apple.com/documentation/appstoreconnectapi/app_store_connect_api_release_notes)：了解最新更新
- [最佳实践指南](https://developer.apple.com/app-store-connect/api/guidelines)：官方集成建议

## 总结

App Store Connect API 为 Lumi 插件提供了完整的功能基础，可以实现：
- ✅ 应用信息编辑（名称、描述、关键词等）
- ✅ 宣传图和截图上传管理
- ✅ 应用版本创建和管理
- ✅ 审核提交流程自动化
- ✅ 多语言本地化支持
- ✅ 应用状态监控

通过集成这个 API，Lumi 可以为开发者提供一站式的应用上架体验，无需在多个工具间切换，显著提升开发效率和工作流程的连贯性。