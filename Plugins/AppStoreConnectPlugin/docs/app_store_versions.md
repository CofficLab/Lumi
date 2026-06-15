# App Store Versions API

App Store Versions 资源代表应用在 App Store 上的版本信息，包括版本状态、发布类型、元数据等。

## Resource Information

- **Type**: `appStoreVersions`
- **Base Path**: `/v1/appStoreVersions`

## Endpoints

### List All App Store Versions

获取应用的所有 App Store 版本。

```
GET /v1/appStoreVersions
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[app]` | string[] | No | 按应用 ID 过滤 |
| `filter[platform]` | string[] | No | 按平台过滤：`IOS`, `MAC_OS`, `TV_OS` |
| `filter[appStoreState]` | string[] | No | 按状态过滤 |
| `filter[versionString]` | string[] | No | 按版本号过滤 |
| `sort` | string | No | 排序字段：`createdDate`, `-createdDate`, `versionString`, `-versionString` |
| `fields[appStoreVersions]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "appStoreVersions",
      "id": "123456",
      "attributes": {
        "versionString": "1.0.0",
        "platform": "IOS",
        "appStoreState": "READY_FOR_SALE",
        "appVersionState": "READY_FOR_SALE",
        "copyright": "© 2024 Example Inc.",
        "downloadable": true,
        "earliestReleaseDate": null,
        "createdDate": "2024-01-15T10:30:00.000+00:00",
        "releaseType": "AFTER_APPROVAL",
        "usesIdfa": false
      },
      "relationships": {
        "app": {
          "data": {
            "type": "apps",
            "id": "123456789"
          }
        },
        "build": {
          "data": {
            "type": "builds",
            "id": "build-123"
          }
        },
        "appStoreVersionSubmission": {
          "links": {
            "self": "/v1/appStoreVersions/123456/relationships/appStoreVersionSubmission",
            "related": "/v1/appStoreVersions/123456/appStoreVersionSubmission"
          }
        },
        "appStoreVersionPhasedRelease": {
          "links": {
            "self": "/v1/appStoreVersions/123456/relationships/appStoreVersionPhasedRelease",
            "related": "/v1/appStoreVersions/123456/appStoreVersionPhasedRelease"
          }
        }
      },
      "links": {
        "self": "/v1/appStoreVersions/123456"
      }
    }
  ],
  "links": {
    "self": "https://api.appstoreconnect.apple.com/v1/appStoreVersions"
  }
}
```

### Read App Store Version Information

获取特定 App Store 版本的信息。

```
GET /v1/appStoreVersions/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | App Store 版本 ID |

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `fields[appStoreVersions]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |

#### Response

```json
{
  "data": {
    "type": "appStoreVersions",
    "id": "123456",
    "attributes": {
      "versionString": "1.0.0",
      "platform": "IOS",
      "appStoreState": "READY_FOR_SALE",
      "appVersionState": "READY_FOR_SALE",
      "copyright": "© 2024 Example Inc.",
      "downloadable": true,
      "releaseType": "AFTER_APPROVAL",
      "createdDate": "2024-01-15T10:30:00.000+00:00"
    },
    "relationships": {
      "app": {
        "data": {
          "type": "apps",
          "id": "123456789"
        }
      },
      "build": {
        "data": {
          "type": "builds",
          "id": "build-123"
        }
      }
    },
    "links": {
      "self": "/v1/appStoreVersions/123456"
    }
  }
}
```

### Create an App Store Version

创建新的 App Store 版本。

```
POST /v1/appStoreVersions
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersions",
    "attributes": {
      "versionString": "1.1.0",
      "platform": "IOS",
      "copyright": "© 2024 Example Inc.",
      "releaseType": "AFTER_APPROVAL"
    },
    "relationships": {
      "app": {
        "data": {
          "type": "apps",
          "id": "123456789"
        }
      }
    }
  }
}
```

#### Response

```json
{
  "data": {
    "type": "appStoreVersions",
    "id": "123457",
    "attributes": {
      "versionString": "1.1.0",
      "platform": "IOS",
      "appStoreState": "DEVELOPER_REJECTED",
      "copyright": "© 2024 Example Inc.",
      "releaseType": "AFTER_APPROVAL"
    }
  }
}
```

### Update an App Store Version

更新 App Store 版本信息。

```
PATCH /v1/appStoreVersions/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | App Store 版本 ID |

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersions",
    "id": "123456",
    "attributes": {
      "copyright": "© 2024 New Copyright",
      "downloadable": true,
      "releaseType": "MANUAL",
      "earliestReleaseDate": "2024-02-01T00:00:00.000+00:00"
    }
  }
}
```

### Delete an App Store Version

删除 App Store 版本。

```
DELETE /v1/appStoreVersions/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | App Store 版本 ID |

#### Response

```
HTTP/1.1 204 No Content
```

## Object Schema

### App Store Version Object

```json
{
  "type": "appStoreVersions",
  "id": "string",
  "attributes": {
    "versionString": "string",
    "platform": "string",
    "appStoreState": "string",
    "appVersionState": "string",
    "copyright": "string",
    "downloadable": "boolean",
    "earliestReleaseDate": "string|null",
    "createdDate": "string",
    "releaseType": "string",
    "usesIdfa": "boolean"
  },
  "relationships": {
    "app": "object",
    "build": "object",
    "appStoreVersionSubmission": "object",
    "appStoreVersionPhasedRelease": "object",
    "appStoreReviewDetail": "object",
    "appStoreVersionLocalizations": "object"
  },
  "links": {
    "self": "string"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `versionString` | string | 版本号字符串（如 "1.0.0"） |
| `platform` | string | 平台：`IOS`, `MAC_OS`, `TV_OS` |
| `appStoreState` | string | App Store 状态 |
| `appVersionState` | string | 版本状态 |
| `copyright` | string | 版权信息 |
| `downloadable` | boolean | 是否可下载 |
| `earliestReleaseDate` | string\|null | 最早发布日期（ISO 8601 格式） |
| `createdDate` | string | 创建日期 |
| `releaseType` | string | 发布类型：`MANUAL`, `AFTER_APPROVAL`, `SCHEDULED` |
| `usesIdfa` | boolean | 是否使用 IDFA |

## App Store States

| State | Description |
|-------|-------------|
| `DEVELOPER_REJECTED` | 开发者拒绝 |
| `DEVELOPER_REMOVED_FROM_SALE` | 开发者从销售中移除 |
| `METADATA_REJECTED` | 元数据被拒绝 |
| `PREPARE_FOR_SUBMISSION` | 准备提交 |
| `PROCESSING_FOR_DISTRIBUTION` | 处理分发 |
| `READY_FOR_SALE` | 准备销售 |
| `REJECTED` | 被拒绝 |
| `REMOVED_FROM_SALE` | 从销售中移除 |
| `WAITING_FOR_EXPORT_COMPLIANCE` | 等待出口合规 |
| `WAITING_FOR_REVIEW` | 等待审核 |
| `WAITING_FOR_REVIEWER_ACTION` | 等待审核员操作 |
| `REPLACED_WITH_NEW_VERSION` | 被新版本替换 |

## Release Types

| Type | Description |
|------|-------------|
| `MANUAL` | 手动发布 |
| `AFTER_APPROVAL` | 审核通过后自动发布 |
| `SCHEDULED` | 按计划日期发布 |

## Related Documentation

- [Apps API](apps.md)
- [Builds API](builds.md)
- [App Store Version Submissions API](app_store_version_submissions.md)
- [App Store Version Phased Releases API](app_store_version_phased_releases.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [App Store Versions - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_store_versions)
