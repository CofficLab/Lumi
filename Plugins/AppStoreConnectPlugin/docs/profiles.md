# Profiles API

管理 Provisioning Profile，用于应用签名和分发。

## Resource Information

- **Type**: `profiles`
- **Base Path**: `/v1/profiles`

## Endpoints

### List Profiles

获取 Provisioning Profile 列表。

```
GET /v1/profiles
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[name]` | string[] | No | 按名称过滤 |
| `filter[profileType]` | string[] | No | 按类型过滤 |
| `filter[profileState]` | string[] | No | 按状态过滤：`ACTIVE`, `INVALID` |
| `sort` | string | No | 排序字段 |
| `fields[profiles]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源：`bundleId`, `certificates`, `devices` |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "profiles",
      "id": "profile-123",
      "attributes": {
        "name": "My App Development",
        "profileType": "IOS_APP_DEVELOPMENT",
        "profileState": "ACTIVE",
        "profileContent": "base64-encoded-profile-content",
        "uuid": "12345678-1234-1234-1234-1234567890AB",
        "createdDate": "2024-01-15T10:30:00.000+00:00",
        "expirationDate": "2025-01-15T10:30:00.000+00:00"
      },
      "relationships": {
        "bundleId": {
          "data": {
            "type": "bundleIds",
            "id": "bundle-123"
          }
        },
        "certificates": {
          "data": [
            {
              "type": "certificates",
              "id": "cert-123"
            }
          ]
        },
        "devices": {
          "data": [
            {
              "type": "devices",
              "id": "device-123"
            }
          ]
        }
      },
      "links": {
        "self": "/v1/profiles/profile-123"
      }
    }
  ]
}
```

### Read Profile

获取特定 Profile 的信息。

```
GET /v1/profiles/{id}
```

### Create a Profile

创建新的 Provisioning Profile。

```
POST /v1/profiles
```

#### Request Body

```json
{
  "data": {
    "type": "profiles",
    "attributes": {
      "name": "My App Development Profile",
      "profileType": "IOS_APP_DEVELOPMENT"
    },
    "relationships": {
      "bundleId": {
        "data": {
          "type": "bundleIds",
          "id": "bundle-123"
        }
      },
      "certificates": {
        "data": [
          {
            "type": "certificates",
            "id": "cert-123"
          }
        ]
      },
      "devices": {
        "data": [
          {
            "type": "devices",
            "id": "device-123"
          }
        ]
      }
    }
  }
}
```

### Delete a Profile

删除 Provisioning Profile。

```
DELETE /v1/profiles/{id}
```

## Object Schema

```json
{
  "type": "profiles",
  "id": "string",
  "attributes": {
    "name": "string",
    "profileType": "string",
    "profileState": "string",
    "profileContent": "string",
    "uuid": "string",
    "createdDate": "string",
    "expirationDate": "string"
  },
  "relationships": {
    "bundleId": "object",
    "certificates": "object",
    "devices": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | Profile 名称 |
| `profileType` | string | Profile 类型 |
| `profileState` | string | 状态：`ACTIVE`, `INVALID` |
| `profileContent` | string | Base64 编码的 Profile 内容 |
| `uuid` | string | UUID |
| `createdDate` | string | 创建日期 |
| `expirationDate` | string | 过期日期 |

## Profile Types

### Development

| Type | Description |
|------|-------------|
| `IOS_APP_DEVELOPMENT` | iOS 应用开发 |
| `MAC_APP_DEVELOPMENT` | macOS 应用开发 |
| `TVOS_APP_DEVELOPMENT` | tvOS 应用开发 |
| `WATCHKIT_APP_DEVELOPMENT` | watchOS 应用开发 |

### Distribution

| Type | Description |
|------|-------------|
| `IOS_APP_STORE` | iOS App Store 发布 |
| `IOS_APP_ADHOC` | iOS Ad Hoc 发布 |
| `IOS_APP_INHOUSE` | iOS 企业内部分发 |
| `MAC_APP_STORE` | macOS App Store 发布 |
| `MAC_APP_DIRECT` | macOS 直接发布 |
| `MAC_CATALYST_APP_DIRECT` | Mac Catalyst 直接发布 |

## Profile States

| State | Description |
|-------|-------------|
| `ACTIVE` | 有效 |
| `INVALID` | 无效（证书过期、设备移除等） |

## Workflow

1. **创建 Bundle ID**
   ```
   POST /v1/bundleIds
   ```

2. **创建/获取证书**
   ```
   POST /v1/certificates
   ```

3. **注册设备**（仅开发/Ad Hoc）
   ```
   POST /v1/devices
   ```

4. **创建 Profile**
   ```
   POST /v1/profiles
   ```

5. **安装 Profile**
   - 下载 `profileContent`
   - 保存为 `.mobileprovision` 文件
   - 双击安装到 Xcode

## Related Documentation

- [Bundle IDs API](bundle_ids.md)
- [Certificates API](certificates.md)
- [Devices API](devices.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Profiles - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/profiles)
