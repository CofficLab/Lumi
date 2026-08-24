# Apps API

Apps 资源代表你在 App Store Connect 中的应用，包括正在开发或已在 App Store 上架的应用。

## Resource Information

- **Type**: `apps`
- **Base Path**: `/v1/apps`

## Endpoints

### List Apps

获取应用的列表。

```
GET /v1/apps
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[bundleId]` | string[] | No | 按 bundle ID 过滤 |
| `filter[id]` | string[] | No | 按应用 ID 过滤 |
| `filter[name]` | string[] | No | 按应用名称过滤 |
| `filter[sku]` | string[] | No | 按 SKU 过滤 |
| `filter[appStoreVersions.platform]` | string[] | No | 按平台过滤 |
| `sort` | string | No | 排序字段：`bundleId`, `-bundleId`, `name`, `-name`, `sku`, `-sku` |
| `fields[apps]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |
| `limit[appStoreVersions]` | integer | No | 关联资源的每页数量 |

#### Response

```json
{
  "data": [
    {
      "type": "apps",
      "id": "123456789",
      "attributes": {
        "bundleId": "com.example.app",
        "name": "My App",
        "primaryLocale": "en-US",
        "sku": "my-app-sku",
        "isOrEverWasMadeForKids": false,
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT",
        "subscriptionStatusUrl": null,
        "subscriptionStatusUrlVersion": null,
        "subscriptionStatusUrlForSandbox": null,
        "subscriptionStatusUrlVersionForSandbox": null
      },
      "relationships": {
        "appStoreVersions": {
          "data": [
            {
              "type": "appStoreVersions",
              "id": "123456"
            }
          ],
          "links": {
            "self": "/v1/apps/123456789/relationships/appStoreVersions",
            "related": "/v1/apps/123456789/appStoreVersions"
          }
        },
        "betaGroups": {
          "links": {
            "self": "/v1/apps/123456789/relationships/betaGroups",
            "related": "/v1/apps/123456789/betaGroups"
          }
        },
        "builds": {
          "links": {
            "self": "/v1/apps/123456789/relationships/builds",
            "related": "/v1/apps/123456789/builds"
          }
        }
      },
      "links": {
        "self": "/v1/apps/123456789"
      }
    }
  ],
  "links": {
    "self": "https://api.appstoreconnect.apple.com/v1/apps",
    "next": "https://api.appstoreconnect.apple.com/v1/apps?cursor=abc123"
  },
  "meta": {
    "paging": {
      "total": 1,
      "limit": 50
    }
  }
}
```

### Read App Information

获取特定应用的信息。

```
GET /v1/apps/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | 应用 ID |

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `fields[apps]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |

#### Response

```json
{
  "data": {
    "type": "apps",
    "id": "123456789",
    "attributes": {
      "bundleId": "com.example.app",
      "name": "My App",
      "primaryLocale": "en-US",
      "sku": "my-app-sku"
    },
    "links": {
      "self": "/v1/apps/123456789"
    }
  },
  "links": {
    "self": "https://api.appstoreconnect.apple.com/v1/apps/123456789"
  }
}
```

### Modify an App

更新应用信息，包括 bundle ID、主要语言环境、价格计划和全球可用性。

```
PATCH /v1/apps/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | 应用 ID |

#### Request Body

```json
{
  "data": {
    "type": "apps",
    "id": "123456789",
    "attributes": {
      "bundleId": "com.example.newapp",
      "primaryLocale": "zh-Hans",
      "contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"
    }
  }
}
```

#### Response

```json
{
  "data": {
    "type": "apps",
    "id": "123456789",
    "attributes": {
      "bundleId": "com.example.newapp",
      "name": "My App",
      "primaryLocale": "zh-Hans"
    }
  }
}
```

## Related Resources

### Builds

获取应用的所有构建版本。

```
GET /v1/apps/{id}/builds
```

#### Response

```json
{
  "data": [
    {
      "type": "builds",
      "id": "build-123",
      "attributes": {
        "version": "1.0.0",
        "uploadedDate": "2024-01-15T10:30:00Z",
        "processingState": "VALID"
      }
    }
  ]
}
```

### App Store Versions

获取应用的所有 App Store 版本。

```
GET /v1/apps/{id}/appStoreVersions
```

#### Response

```json
{
  "data": [
    {
      "type": "appStoreVersions",
      "id": "version-123",
      "attributes": {
        "versionString": "1.0.0",
        "platform": "IOS",
        "appStoreState": "READY_FOR_SALE"
      }
    }
  ]
}
```

### Beta Groups

获取应用的所有 Beta 测试组。

```
GET /v1/apps/{id}/betaGroups
```

### Beta App Localizations

获取应用的所有 Beta 测试本地化信息。

```
GET /v1/apps/{id}/betaAppLocalizations
```

### Beta License Agreement

获取应用的 Beta 测试许可协议。

```
GET /v1/apps/{id}/betaLicenseAgreement
```

## Object Schema

### App Object

```json
{
  "type": "apps",
  "id": "string",
  "attributes": {
    "bundleId": "string",
    "name": "string",
    "primaryLocale": "string",
    "sku": "string",
    "isOrEverWasMadeForKids": "boolean",
    "contentRightsDeclaration": "string",
    "subscriptionStatusUrl": "string|null",
    "subscriptionStatusUrlVersion": "integer|null",
    "subscriptionStatusUrlForSandbox": "string|null",
    "subscriptionStatusUrlVersionForSandbox": "integer|null"
  },
  "relationships": {
    "appStoreVersions": "object",
    "betaGroups": "object",
    "builds": "object",
    "betaAppLocalizations": "object",
    "betaAppReviewDetail": "object",
    "betaLicenseAgreement": "object",
    "preReleaseVersions": "object",
    "prices": "object",
    "inAppPurchases": "object",
    "gameCenterEnabledVersions": "object"
  },
  "links": {
    "self": "string"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `bundleId` | string | 应用的 Bundle ID |
| `name` | string | 应用名称 |
| `primaryLocale` | string | 主要语言环境 (如 `en-US`, `zh-Hans`) |
| `sku` | string | 应用 SKU |
| `isOrEverWasMadeForKids` | boolean | 是否曾经是为儿童制作的应用 |
| `contentRightsDeclaration` | string | 内容权利声明 |
| `subscriptionStatusUrl` | string\|null | 订阅状态 URL |
| `subscriptionStatusUrlVersion` | integer\|null | 订阅状态 URL 版本 |
| `subscriptionStatusUrlForSandbox` | string\|null | 沙盒环境的订阅状态 URL |
| `subscriptionStatusUrlVersionForSandbox` | integer\|null | 沙盒环境的订阅状态 URL 版本 |

## Error Responses

### 400 Bad Request

```json
{
  "errors": [
    {
      "status": "400",
      "code": "PARAMETER_ERROR.INVALID",
      "title": "A parameter has an invalid value",
      "detail": "The 'bundleId' parameter is invalid"
    }
  ]
}
```

### 404 Not Found

```json
{
  "errors": [
    {
      "status": "404",
      "code": "NOT_FOUND",
      "title": "The requested resource was not found",
      "detail": "The app with ID '123456789' was not found"
    }
  ]
}
```

## Related Documentation

- [App Store Versions API](app_store_versions.md)
- [Builds API](builds.md)
- [Beta Testers API](beta_testers.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Apps - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/apps)
