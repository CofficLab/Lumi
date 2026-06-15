# In-App Purchases API

管理应用内购买项目，包括消耗型、非消耗型和自动续期订阅。

## Resource Information

- **Type**: `inAppPurchases`
- **Base Path**: `/v2/inAppPurchases` (v2) / `/v1/inAppPurchases` (v1, deprecated)

## Endpoints

### List In-App Purchases

获取应用的所有应用内购买项目。

```
GET /v2/inAppPurchases
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[app]` | string[] | No | 按应用 ID 过滤 |
| `filter[inAppPurchaseType]` | string[] | No | 按类型过滤 |
| `filter[name]` | string[] | No | 按名称过滤 |
| `filter[productId]` | string[] | No | 按产品 ID 过滤 |
| `sort` | string | No | 排序字段 |
| `fields[inAppPurchases]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "inAppPurchases",
      "id": "iap-123",
      "attributes": {
        "productId": "com.example.premium",
        "referenceName": "Premium Upgrade",
        "inAppPurchaseType": "NON_CONSUMABLE",
        "state": "APPROVED",
        "reviewNote": "Premium features unlock note",
        "familySharable": false,
        "contentHosting": false,
        "contentHostingEnabled": false
      },
      "relationships": {
        "app": {
          "data": {
            "type": "apps",
            "id": "app-123"
          }
        },
        "promotedPurchase": {
          "links": {
            "self": "/v2/inAppPurchases/iap-123/relationships/promotedPurchase",
            "related": "/v2/inAppPurchases/iap-123/promotedPurchase"
          }
        },
        "content": {
          "links": {
            "self": "/v2/inAppPurchases/iap-123/relationships/content",
            "related": "/v2/inAppPurchases/iap-123/content"
          }
        },
        "pricePoints": {
          "links": {
            "self": "/v2/inAppPurchases/iap-123/relationships/pricePoints",
            "related": "/v2/inAppPurchases/iap-123/pricePoints"
          }
        }
      },
      "links": {
        "self": "/v2/inAppPurchases/iap-123"
      }
    }
  ]
}
```

### Read In-App Purchase

获取特定应用内购买项目信息。

```
GET /v2/inAppPurchases/{id}
```

### Create an In-App Purchase

创建新的应用内购买项目。

```
POST /v2/inAppPurchases
```

#### Request Body

```json
{
  "data": {
    "type": "inAppPurchases",
    "attributes": {
      "productId": "com.example.coins.100",
      "referenceName": "100 Coins Pack",
      "inAppPurchaseType": "CONSUMABLE",
      "reviewNote": "Virtual currency for in-app use"
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

### Update an In-App Purchase

更新应用内购买项目信息。

```
PATCH /v2/inAppPurchases/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "inAppPurchases",
    "id": "iap-123",
    "attributes": {
      "referenceName": "Updated Name",
      "reviewNote": "Updated review note",
      "familySharable": true
    }
  }
}
```

### Delete an In-App Purchase

删除应用内购买项目。

```
DELETE /v2/inAppPurchases/{id}
```

## Object Schema

```json
{
  "type": "inAppPurchases",
  "id": "string",
  "attributes": {
    "productId": "string",
    "referenceName": "string",
    "inAppPurchaseType": "string",
    "state": "string",
    "reviewNote": "string",
    "familySharable": "boolean",
    "contentHosting": "boolean",
    "contentHostingEnabled": "boolean"
  },
  "relationships": {
    "app": "object",
    "promotedPurchase": "object",
    "content": "object",
    "pricePoints": "object",
    "inAppPurchaseLocalizations": "object",
    "iapPriceSchedule": "object",
    "subscription": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `productId` | string | 产品 ID（在 App Store Connect 中唯一） |
| `referenceName` | string | 参考名称（内部使用） |
| `inAppPurchaseType` | string | 购买类型 |
| `state` | string | 状态 |
| `reviewNote` | string | 审核说明（给审核员看的） |
| `familySharable` | boolean | 是否支持家庭共享 |
| `contentHosting` | boolean | 是否托管内容 |
| `contentHostingEnabled` | boolean | 内容托管是否启用 |

## In-App Purchase Types

| Type | Description |
|------|-------------|
| `CONSUMABLE` | 消耗型（可重复购买） |
| `NON_CONSUMABLE` | 非消耗型（一次性购买） |
| `NON_RENEWING_SUBSCRIPTION` | 非续期订阅 |
| `AUTO_RENEWABLE_SUBSCRIPTION` | 自动续期订阅 |

## States

| State | Description |
|-------|-------------|
| `MISSING_METADATA` | 缺少元数据 |
| `READY_TO_SUBMIT` | 准备提交 |
| `WAITING_FOR_REVIEW` | 等待审核 |
| `IN_REVIEW` | 审核中 |
| `APPROVED` | 已批准 |
| `DEVELOPER_ACTION_NEEDED` | 需要开发者操作 |
| `REMOVED_FROM_SALE` | 从销售中移除 |
| `REJECTED` | 已拒绝 |

## Notes

- Product ID 创建后不能修改
- 消耗型产品不支持家庭共享
- 每个应用最多可以有 10,000 个应用内购买项目
- 自动续期订阅需要配置 Subscription Group

## Related Documentation

- [Apps API](apps.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [In-App Purchases V2 - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/inapppurchasesv2)
