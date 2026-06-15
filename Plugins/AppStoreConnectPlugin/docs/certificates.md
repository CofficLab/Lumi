# Certificates API

管理签名证书，包括开发和发布证书。

## Resource Information

- **Type**: `certificates`
- **Base Path**: `/v1/certificates`

## Endpoints

### List Certificates

获取证书列表。

```
GET /v1/certificates
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[certificateType]` | string[] | No | 按证书类型过滤 |
| `filter[displayName]` | string[] | No | 按显示名称过滤 |
| `filter[serialNumber]` | string[] | No | 按序列号过滤 |
| `sort` | string | No | 排序字段：`certificateType`, `-certificateType`, `displayName`, `-displayName`, `serialNumber`, `-serialNumber` |
| `fields[certificates]` | string[] | No | 指定返回的字段 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "certificates",
      "id": "cert-123",
      "attributes": {
        "name": "Apple Development: John Doe (ABC123DEF4)",
        "certificateType": "IOS_DEVELOPMENT",
        "displayName": "Apple Development: John Doe",
        "serialNumber": "1234567890ABCDEF",
        "platform": "IOS",
        "expirationDate": "2025-01-15T10:30:00.000+00:00"
      },
      "links": {
        "self": "/v1/certificates/cert-123"
      }
    }
  ]
}
```

### Read Certificate

获取特定证书的信息。

```
GET /v1/certificates/{id}
```

### Create a Certificate

创建新证书。

```
POST /v1/certificates
```

#### Request Body

```json
{
  "data": {
    "attributes": {
      "csrContent": "-----BEGIN CERTIFICATE REQUEST-----\n...\n-----END CERTIFICATE REQUEST-----",
      "certificateType": "IOS_DEVELOPMENT"
    }
  }
}
```

**注意**: CSR (Certificate Signing Request) 需要先用本地密钥对生成。

#### Response

```json
{
  "data": {
    "type": "certificates",
    "id": "cert-456",
    "attributes": {
      "name": "Apple Development: Jane Smith",
      "certificateType": "IOS_DEVELOPMENT",
      "displayName": "Apple Development: Jane Smith",
      "serialNumber": "ABCDEF1234567890",
      "certificateContent": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
      "expirationDate": "2025-06-15T10:30:00.000+00:00"
    }
  }
}
```

### Revoke a Certificate

撤销证书。

```
DELETE /v1/certificates/{id}
```

### Download Certificate

下载证书内容。

```
GET /v1/certificates/{id}
```

在请求中指定 `fields[certificates]=certificateContent` 获取证书内容。

## Object Schema

```json
{
  "type": "certificates",
  "id": "string",
  "attributes": {
    "name": "string",
    "certificateType": "string",
    "displayName": "string",
    "serialNumber": "string",
    "platform": "string",
    "expirationDate": "string",
    "certificateContent": "string"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | 证书全名 |
| `certificateType` | string | 证书类型 |
| `displayName` | string | 显示名称 |
| `serialNumber` | string | 序列号 |
| `platform` | string | 平台 |
| `expirationDate` | string | 过期日期 |
| `certificateContent` | string | 证书 PEM 内容 |

## Certificate Types

| Type | Description |
|------|-------------|
| `IOS_DEVELOPMENT` | iOS 开发证书 |
| `IOS_DISTRIBUTION` | iOS 发布证书 |
| `MAC_APP_DEVELOPMENT` | macOS 应用开发证书 |
| `MAC_APP_DISTRIBUTION` | macOS 应用发布证书 |
| `MAC_INSTALLER_DISTRIBUTION` | macOS 安装程序发布证书 |
| `MAC_APP_DIRECT_DISTRIBUTION` | macOS 应用直接发布证书 |

## Certificate Limits

| Type | Maximum |
|------|---------|
| Development | 每个团队成员 |
| Distribution | 每个团队 |

## Workflow

1. **生成 CSR**
   - 使用 Keychain Access 或 `openssl` 生成 CSR
   - 包含本地公钥

2. **提交 CSR 创建证书**
   ```
   POST /v1/certificates
   ```

3. **保存证书**
   - 从响应中获取 `certificateContent`
   - 导入到 Keychain 或保存为 `.cer` 文件

4. **使用证书签名**
   - 配合私钥和 Provisioning Profile 进行代码签名

## Related Documentation

- [Profiles API](profiles.md)
- [Bundle IDs API](bundle_ids.md)
- [Devices API](devices.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Certificates - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/certificates)
