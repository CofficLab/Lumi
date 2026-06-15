# Bundle IDs API

管理应用的 Bundle ID，用于标识应用的唯一标识符。

## Resource Information

- **Type**: `bundleIds`
- **Base Path**: `/v1/bundleIds`

## Endpoints

### List Bundle IDs

获取 Bundle ID 列表。

```
GET /v1/bundleIds
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[identifier]` | string[] | No | 按 Bundle ID 标识符过滤 |
| `filter[name]` | string[] | No | 按名称过滤 |
| `filter[platform]` | string[] | No | 按平台过滤：`IOS`, `MAC_OS`, `UNIVERSAL` |
| `filter[id]` | string[] | No | 按 ID 过滤 |
| `sort` | string | No | 排序字段：`id`, `-id`, `identifier`, `-identifier`, `name`, `-name`, `platform`, `-platform` |
| `fields[bundleIds]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "bundleIds",
      "id": "bundle-123",
      "attributes": {
        "identifier": "com.example.myapp",
        "name": "My App",
        "platform": "IOS",
        "seedId": "ABC123DEF4"
      },
      "relationships": {
        "profiles": {
          "links": {
            "self": "/v1/bundleIds/bundle-123/relationships/profiles",
            "related": "/v1/bundleIds/bundle-123/profiles"
          }
        },
        "bundleIdCapabilities": {
          "links": {
            "self": "/v1/bundleIds/bundle-123/relationships/bundleIdCapabilities",
            "related": "/v1/bundleIds/bundle-123/bundleIdCapabilities"
          }
        }
      },
      "links": {
        "self": "/v1/bundleIds/bundle-123"
      }
    }
  ]
}
```

### Read Bundle ID

获取特定 Bundle ID 的信息。

```
GET /v1/bundleIds/{id}
```

### Register a Bundle ID

注册新的 Bundle ID。

```
POST /v1/bundleIds
```

#### Request Body

```json
{
  "data": {
    "type": "bundleIds",
    "attributes": {
      "identifier": "com.example.newapp",
      "name": "My New App",
      "platform": "IOS"
    }
  }
}
```

#### Response

```json
{
  "data": {
    "type": "bundleIds",
    "id": "bundle-456",
    "attributes": {
      "identifier": "com.example.newapp",
      "name": "My New App",
      "platform": "IOS",
      "seedId": "DEF456GHI7"
    }
  }
}
```

### Update a Bundle ID

更新 Bundle ID 的名称。

```
PATCH /v1/bundleIds/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "bundleIds",
    "id": "bundle-123",
    "attributes": {
      "name": "Updated App Name"
    }
  }
}
```

### Delete a Bundle ID

删除 Bundle ID。

```
DELETE /v1/bundleIds/{id}
```

## Object Schema

```json
{
  "type": "bundleIds",
  "id": "string",
  "attributes": {
    "identifier": "string",
    "name": "string",
    "platform": "string",
    "seedId": "string"
  },
  "relationships": {
    "profiles": "object",
    "bundleIdCapabilities": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `identifier` | string | Bundle ID 标识符（如 `com.example.app`） |
| `name` | string | 显示名称 |
| `platform` | string | 平台：`IOS`, `MAC_OS`, `UNIVERSAL` |
| `seedId` | string | Team ID |

## Platforms

| Platform | Description |
|----------|-------------|
| `IOS` | iOS/iPadOS |
| `MAC_OS` | macOS |
| `UNIVERSAL` | 通用（iOS + macOS） |

## Notes

- Bundle ID 一旦注册不能修改标识符
- 删除 Bundle ID 会同时删除关联的配置文件和证书
- Wildcard Bundle ID（如 `com.example.*`）不能在 API 中注册

## Related Documentation

- [Bundle ID Capabilities API](bundle_id_capabilities.md)
- [Profiles API](profiles.md)
- [Certificates API](certificates.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Bundle IDs - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/bundle_ids)
