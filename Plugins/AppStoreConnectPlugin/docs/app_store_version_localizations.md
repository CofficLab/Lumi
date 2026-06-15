# App Store Version Localizations API

管理 App Store 版本的本地化信息，包括描述、关键词、截图等。

## Resource Information

- **Type**: `appStoreVersionLocalizations`
- **Base Path**: `/v1/appStoreVersionLocalizations`

## Endpoints

### List All Localizations

获取 App Store 版本的所有本地化信息。

```
GET /v1/appStoreVersionLocalizations
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[appStoreVersion]` | string[] | No | 按版本 ID 过滤 |
| `filter[locale]` | string[] | No | 按语言环境过滤 |
| `fields[appStoreVersionLocalizations]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 |

### Read Localization

获取特定的本地化信息。

```
GET /v1/appStoreVersionLocalizations/{id}
```

### Create a Localization

创建新的本地化信息。

```
POST /v1/appStoreVersionLocalizations
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersionLocalizations",
    "attributes": {
      "locale": "zh-Hans",
      "description": "这是应用描述，最多4000个字符。",
      "keywords": "关键词1,关键词2,关键词3",
      "marketingUrl": "https://example.com",
      "promotionalText": "促销文本，最多170个字符",
      "supportUrl": "https://example.com/support",
      "whatsNew": "新版本更新说明，最多4000个字符。"
    },
    "relationships": {
      "appStoreVersion": {
        "data": {
          "type": "appStoreVersions",
          "id": "123456"
        }
      }
    }
  }
}
```

### Update a Localization

更新本地化信息。

```
PATCH /v1/appStoreVersionLocalizations/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersionLocalizations",
    "id": "loc-123",
    "attributes": {
      "description": "更新后的应用描述",
      "keywords": "新关键词1,新关键词2",
      "whatsNew": "更新后的新功能说明"
    }
  }
}
```

### Delete a Localization

删除本地化信息。

```
DELETE /v1/appStoreVersionLocalizations/{id}
```

## Object Schema

```json
{
  "type": "appStoreVersionLocalizations",
  "id": "string",
  "attributes": {
    "locale": "string",
    "description": "string",
    "keywords": "string",
    "marketingUrl": "string",
    "promotionalText": "string",
    "supportUrl": "string",
    "whatsNew": "string"
  },
  "relationships": {
    "appStoreVersion": "object",
    "appScreenshotSets": "object",
    "appPreviewSets": "object"
  }
}
```

### Attributes

| Attribute | Type | Max Length | Description |
|-----------|------|------------|-------------|
| `locale` | string | - | 语言环境代码（如 `en-US`, `zh-Hans`） |
| `description` | string | 4000 | 应用描述 |
| `keywords` | string | 100 | 关键词，逗号分隔 |
| `marketingUrl` | string | - | 营销网址 |
| `promotionalText` | string | 170 | 促销文本 |
| `supportUrl` | string | - | 支持网址 |
| `whatsNew` | string | 4000 | 新功能说明 |

## Locale Codes

常用语言环境代码：

| Code | Language |
|------|----------|
| `en-US` | 英语（美国） |
| `en-GB` | 英语（英国） |
| `zh-Hans` | 简体中文 |
| `zh-Hant` | 繁体中文 |
| `ja` | 日语 |
| `ko` | 韩语 |
| `de-DE` | 德语 |
| `fr-FR` | 法语 |
| `es-ES` | 西班牙语 |
| `pt-BR` | 葡萄牙语（巴西） |

## Related Documentation

- [App Store Versions API](app_store_versions.md)
- [App Screenshots API](app_screenshots.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [App Store Version Localizations - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_store_version_localizations)
