# App Store Connect API 认证和通用信息

## 基本信息

**API 版本**: 1.0+  
**基础 URL**: `https://api.appstoreconnect.apple.com`  
**认证方式**: JWT (JSON Web Token)  
**数据格式**: JSON

## 认证机制

### API Key 类型

有两种 API Key 类型：

#### Team Key（团队密钥）
- 访问所有应用
- 权限级别基于所选角色
- 需要 App Store Connect 中的 Admin 账户才能生成

#### Individual Key（个人密钥）
- 访问和权限与关联用户相同
- 无法使用 Provisioning 端点
- 无法访问 Sales and Finance
- 无法使用 `notaryTool`

### 创建 API Key

#### 创建 Team Key 的步骤
1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 选择 **Users and Access**，然后选择 **Integrations** 标签
3. 在左侧栏选择 **App Store Connect API**
4. 确保选择了 **Team Keys** 标签
5. 点击 **Generate API Key** 或 **Add (+)** 按钮
6. 输入密钥名称（仅用于标识，不是密钥的一部分）
7. 在 **Access** 下选择密钥的角色
8. 点击 **Generate**

#### 创建 Individual Key 的步骤
1. 登录 App Store Connect
2. 进入用户配置文件
3. 向下滚动到 **Individual API Key**
4. 点击 **Generate API Key**

### 下载和存储私钥

私钥只能下载一次，下载后 Apple 不保留副本。

**安全注意事项**：
- 将 API Keys 视为敏感凭证（如用户名和密码）
- 不要将密钥存储在代码仓库中
- 不要在客户端代码中包含密钥
- 如果怀疑密钥泄露，立即在 App Store Connect 中撤销

### JWT Token 生成

#### JWT Header 结构

```json
{
    "alg": "ES256",
    "kid": "2X9R4HXF34",
    "typ": "JWT"
}
```

| 字段 | 值 | 说明 |
|------|-----|------|
| `alg` | `ES256` | 加密算法，所有 JWT 必须使用 ES256 |
| `kid` | API Key ID | 从 App Store Connect 获取的私钥 ID，例如 `2X9R4HXF34` |
| `typ` | `JWT` | 令牌类型 |

#### JWT Payload 结构（Team Key）

```json
{
    "iss": "57246542-96fe-1a63-e053-0824d011072a",
    "iat": 1528407600,
    "exp": 1528408800,
    "aud": "appstoreconnect-v1",
    "scope": [
        "GET /v1/apps?filter[platform]=IOS"
    ]
}
```

| 字段 | 值 | 说明 |
|------|-----|------|
| `iss` | Issuer ID | 从 App Store Connect API Keys 页面获取的发行者 ID |
| `iat` | UNIX 时间戳 | 令牌创建时间 |
| `exp` | UNIX 时间戳 | 令牌过期时间（最多 20 分钟，某些资源支持更长） |
| `aud` | `appstoreconnect-v1` | 受众 |
| `scope` | 字符串数组 | 可选，指定令牌允许的操作范围 |

#### JWT Payload 结构（Individual Key）

```json
{
    "sub": "user",
    "iat": 1528407600,
    "exp": 1528408800,
    "aud": "appstoreconnect-v1",
    "scope": [
        "GET /v1/apps/123"
    ]
}
```

| 字段 | 值 | 说明 |
|------|-----|------|
| `sub` | `user` | 主题，个人密钥始终为 `user` |
| `iat` | UNIX 时间戳 | 令牌创建时间 |
| `exp` | UNIX 时间戳 | 令牌过期时间 |
| `aud` | `appstoreconnect-v1` | 受众 |
| `scope` | 字符串数组 | 可选，指定令牌允许的操作范围 |

**注意**：Individual Key 不使用 `iss` 字段，但需要 `sub` 字段。

### 令牌作用域（Scope）

Scope 用于限制令牌的权限范围，提高安全性。每个 scope 条目包含：
- HTTP 方法（如 `GET`）
- URL 路径（如 `/v1/apps`）
- 可选的 URL 查询参数（如 `?filter[platform]=IOS`）

**注意**：查询参数的顺序不重要。Apple 在检查 scope 时忽略以下参数：`limit`、`cursor`、`sort`。

### 令牌生命周期

- 大多数请求：令牌有效期最多 20 分钟
- 某些只读资源：如果令牌定义了 scope 且仅包含 GET 请求，可接受最长 6 个月的令牌

支持长期令牌的资源：
- Build Actions
- Build Runs
- Git References
- Issues
- macOS Versions
- Products
- Providers
- Power and Performance Metrics and Logs
- Pull Requests
- Repositories
- Test Results
- Workflows
- Xcode Versions

**最佳实践**：
- 一次性请求使用 2 分钟的令牌
- 长时间运行的进程使用 20 分钟的令牌
- 定期生成新令牌，而不是使用更长的有效期
- 重用签名令牌以提高性能，直到过期

### 在请求中使用 JWT

将签名后的 JWT 作为 Bearer Token 放在请求的 Authorization Header 中：

```bash
curl -v -H 'Authorization: Bearer [signed token]' \
  "https://api.appstoreconnect.apple.com/v1/apps"
```

## 速率限制

### 限制机制

API 限制同一 API Key 在指定时间段内的请求量。

### 速率限制 Header

每个 API 响应的 HTTP Header 中都包含 `X-Rate-Limit`：

```
user-hour-lim:3500;user-hour-rem:500;
```

| 参数 | 说明 |
|------|------|
| `user-hour-lim` | 每小时可发送的请求数 |
| `user-hour-rem` | 剩余可用的请求数 |

### 时间窗口

使用"滚动小时"机制：在任意时刻，`user-hour-rem` 的值等于每小时限制减去过去 60 分钟内的总请求数。

### 超限错误响应

如果超过每小时限制，API 返回 HTTP 429 响应，错误码为 `RATE_LIMIT_EXCEEDED`。

### 处理建议

1. **节流请求**：定期检查值时，避免超过端点的每小时限制
2. **优雅处理错误**：在错误处理流程中处理 HTTP 429 错误，例如记录失败并将任务排队稍后重试

## 错误处理

API 返回符合 JSON API 规范的错误响应，包含：
- HTTP 状态码
- 错误类型
- 错误详情
- 相关资源信息

常见错误码：
- `RATE_LIMIT_EXCEEDED` - 超过速率限制
- 其他错误参考 [Interpreting and Handling Errors](https://developer.apple.com/documentation/appstoreconnectapi/interpreting-and-handling-errors)

## 分页

对于大型数据集，API 支持分页：
- 使用 `limit` 参数指定每页数量
- 使用 `cursor` 参数获取下一页
- 响应中包含分页链接

参考 [Large Data Sets](https://developer.apple.com/documentation/appstoreconnectapi/large-data-sets)

## 资源上传

支持上传以下资源到 App Store Connect：
- 截图
- 应用预览
- App Review 附件
- 路由应用覆盖文件

参考 [Uploading Assets to App Store Connect](https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect)

## 参考链接

- [App Store Connect API 文档](https://developer.apple.com/documentation/appstoreconnectapi)
- [Creating API Keys for App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Generating Tokens for API Requests](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)
- [Identifying Rate Limits](https://developer.apple.com/documentation/appstoreconnectapi/identifying-rate-limits)
- [JWT.io](https://jwt.io) - JWT 工具库
