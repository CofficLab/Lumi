# Beta App Localizations API

管理 TestFlight 应用的本地化信息，包括测试说明、隐私政策等。

## Resource Information

- **Type**: `betaAppLocalizations`
- **Base Path**: `/v1/betaAppLocalizations`

## Endpoints

### List Beta App Localizations

获取应用的所有 Beta 本地化信息。

```
GET /v1/betaAppLocalizations
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[app]` | string[] | No | 按应用 ID 过滤 |
| `filter[locale]` | string[] | No | 按语言环境过滤 |
| `fields[betaAppLocalizations]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "betaAppLocalizations",
      "id": "beta-loc-123",
      "attributes": {
        "description": "Test description for beta testers",
        "feedbackEmail": "feedback@example.com",
        "locale": "en-US",
        "marketingUrl": "https://example.com",
        "privacyPolicyUrl": "https://example.com/privacy",
        "tvosPrivacyPolicy": null,
        "tvosPrivacyPolicyUrl": null
      },
      "relationships": {
        "app": {
          "data": {
            "type": "apps",
            "id": "app-123"
          }
        }
      },
      "links": {
        "self": "/v1/betaAppLocalizations/beta-loc-123"
      }
    }
  ]
}
```

### Read Beta App Localization

获取特定 Beta 本地化信息。

```
GET /v1/betaAppLocalizations/{id}
```

### Create a Beta App Localization

创建新的 Beta 本地化信息。

```
POST /v1/betaAppLocalizations
```

#### Request Body

```json
{
  "data": {
    "type": "betaAppLocalizations",
    "attributes": {
      "description": "感谢参与测试！这个版本包含新功能 X、Y、Z。",
      "feedbackEmail": "beta-feedback@example.com",
      "locale": "zh-Hans",
      "marketingUrl": "https://example.com/zh",
      "privacyPolicyUrl": "https://example.com/privacy-zh"
    },
    "relationships": {
      "app": {
        "data": {
          "type": "apps",
          "id": "app-123"
        }
      }
    }
  }
}
```

### Update a Beta App Localization

更新 Beta 本地化信息。

```
PATCH /v1/betaAppLocalizations/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "betaAppLocalizations",
    "id": "beta-loc-123",
    "attributes": {
      "description": "Updated test description"
    }
  }
}
```

### Delete a Beta App Localization

删除 Beta 本地化信息。

```
DELETE /v1/betaAppLocalizations/{id}
```

## Object Schema

```json
{
  "type": "betaAppLocalizations",
  "id": "string",
  "attributes": {
    "description": "string",
    "feedbackEmail": "string",
    "locale": "string",
    "marketingUrl": "string",
    "privacyPolicyUrl": "string",
    "tvosPrivacyPolicy": "string|null",
    "tvosPrivacyPolicyUrl": "string|null"
  },
  "relationships": {
    "app": "object"
  }
}
```

### Attributes

| Attribute | Type | Max Length | Description |
|-----------|------|------------|-------------|
| `description` | string | 1000 | Beta 测试说明 |
| `feedbackEmail` | string | - | 反馈邮箱地址 |
| `locale` | string | - | 语言环境代码 |
| `marketingUrl` | string | - | 营销网址 |
| `privacyPolicyUrl` | string | - | 隐私政策网址 |
| `tvosPrivacyPolicy` | string\|null | 2500 | tvOS 隐私政策内容 |
| `tvosPrivacyPolicyUrl` | string\|null | - | tvOS 隐私政策网址 |

## Notes

- 每个应用+语言环境组合只能有一个本地化记录
- Beta 本地化信息会显示给 TestFlight 测试人员
- 建议为每个支持的语言提供本地化信息

## Related Documentation

- [Beta Groups API](beta_groups.md)
- [Beta Testers API](beta_testers.md)
- [Builds API](builds.md)
- [Apps API](apps.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Beta App Localizations - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/beta_app_localizations)
