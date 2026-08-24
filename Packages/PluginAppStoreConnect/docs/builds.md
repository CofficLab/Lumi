# Builds API

Builds 资源代表上传到 App Store Connect 的应用构建版本。

## Resource Information

- **Type**: `builds`
- **Base Path**: `/v1/builds`

## Endpoints

### List Builds

获取构建版本的列表。

```
GET /v1/builds
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[app]` | string[] | No | 按应用 ID 过滤 |
| `filter[id]` | string[] | No | 按构建 ID 过滤 |
| `filter[version]` | string[] | No | 按构建版本号过滤 |
| `filter[processingState]` | string[] | No | 按处理状态过滤：`PROCESSING`, `FAILED`, `VALID`, `INVALID` |
| `filter[expired]` | boolean | No | 按是否过期过滤 |
| `filter[preReleaseVersion.platform]` | string[] | No | 按平台过滤 |
| `sort` | string | No | 排序字段：`version`, `-version`, `uploadedDate`, `-uploadedDate` |
| `fields[builds]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "builds",
      "id": "build-123",
      "attributes": {
        "version": "1.0.0",
        "uploadedDate": "2024-01-15T10:30:00.000+00:00",
        "expirationDate": "2024-04-15T10:30:00.000+00:00",
        "expired": false,
        "minOsVersion": "15.0",
        "processingState": "VALID",
        "usesNonExemptEncryption": false
      },
      "relationships": {
        "app": {
          "data": {
            "type": "apps",
            "id": "123456789"
          }
        },
        "preReleaseVersion": {
          "data": {
            "type": "preReleaseVersions",
            "id": "prerelease-123"
          }
        },
        "betaAppReviewSubmission": {
          "links": {
            "self": "/v1/builds/build-123/relationships/betaAppReviewSubmission",
            "related": "/v1/builds/build-123/betaAppReviewSubmission"
          }
        }
      },
      "links": {
        "self": "/v1/builds/build-123"
      }
    }
  ],
  "links": {
    "self": "https://api.appstoreconnect.apple.com/v1/builds"
  }
}
```

### Read Build Information

获取特定构建版本的信息。

```
GET /v1/builds/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | 构建 ID |

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `fields[builds]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |

### Update Build Information

更新构建信息（如加密声明）。

```
PATCH /v1/builds/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "builds",
    "id": "build-123",
    "attributes": {
      "usesNonExemptEncryption": false
    }
  }
}
```

## Object Schema

### Build Object

```json
{
  "type": "builds",
  "id": "string",
  "attributes": {
    "version": "string",
    "uploadedDate": "string",
    "expirationDate": "string",
    "expired": "boolean",
    "minOsVersion": "string",
    "processingState": "string",
    "usesNonExemptEncryption": "boolean"
  },
  "relationships": {
    "app": "object",
    "preReleaseVersion": "object",
    "betaAppReviewSubmission": "object",
    "buildBetaDetail": "object",
    "betaBuildLocalizations": "object"
  },
  "links": {
    "self": "string"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `version` | string | 构建版本号（如 "1.0.0"） |
| `uploadedDate` | string | 上传日期（ISO 8601） |
| `expirationDate` | string | 过期日期 |
| `expired` | boolean | 是否已过期 |
| `minOsVersion` | string | 最低操作系统版本 |
| `processingState` | string | 处理状态 |
| `usesNonExemptEncryption` | boolean | 是否使用非豁免加密 |

## Processing States

| State | Description |
|-------|-------------|
| `PROCESSING` | 正在处理 |
| `FAILED` | 处理失败 |
| `VALID` | 有效 |
| `INVALID` | 无效 |

## Build Expiration

- Beta 构建在上传后 90 天过期
- 生产构建不会过期
- 过期的构建不能用于 TestFlight

## Upload Builds

**注意**: 不能直接通过 API 上传构建。必须使用：
- Xcode Organizer
- Transporter 应用
- `xcrun altool` 命令行工具
- `xcrun notarytool` (macOS 公证)

## Related Documentation

- [Apps API](apps.md)
- [App Store Versions API](app_store_versions.md)
- [Beta App Review Submissions API](beta_app_review_submissions.md)
- [Pre-release Versions API](pre_release_versions.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Builds - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/builds)
