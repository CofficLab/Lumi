# Beta Groups API

管理 TestFlight 的 Beta 测试组。

## Resource Information

- **Type**: `betaGroups`
- **Base Path**: `/v1/betaGroups`

## Endpoints

### List Beta Groups

获取 Beta 测试组列表。

```
GET /v1/betaGroups
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[app]` | string[] | No | 按应用 ID 过滤 |
| `filter[name]` | string[] | No | 按组名过滤 |
| `filter[isInternalGroup]` | boolean | No | 按是否内部组过滤 |
| `filter[publicLinkEnabled]` | boolean | No | 按是否启用公共链接过滤 |
| `sort` | string | No | 排序字段：`name`, `-name`, `createdDate`, `-createdDate`, `publicLinkEnabled`, `-publicLinkEnabled` |
| `fields[betaGroups]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "betaGroups",
      "id": "group-123",
      "attributes": {
        "name": "Internal Testers",
        "isInternalGroup": true,
        "publicLinkEnabled": false,
        "publicLinkId": "abc123",
        "publicLinkLimit": 1000,
        "publicLink": "https://testflight.apple.com/join/abc123",
        "feedbackEnabled": true,
        "hasAccessToAllBuilds": false,
        "createdDate": "2024-01-15T10:30:00.000+00:00"
      },
      "relationships": {
        "app": {
          "data": {
            "type": "apps",
            "id": "123456789"
          }
        },
        "builds": {
          "links": {
            "self": "/v1/betaGroups/group-123/relationships/builds",
            "related": "/v1/betaGroups/group-123/builds"
          }
        },
        "betaTesters": {
          "links": {
            "self": "/v1/betaGroups/group-123/relationships/betaTesters",
            "related": "/v1/betaGroups/group-123/betaTesters"
          }
        }
      },
      "links": {
        "self": "/v1/betaGroups/group-123"
      }
    }
  ]
}
```

### Read Beta Group

获取特定 Beta 测试组的信息。

```
GET /v1/betaGroups/{id}
```

### Create a Beta Group

创建新的 Beta 测试组。

```
POST /v1/betaGroups
```

#### Request Body

```json
{
  "data": {
    "type": "betaGroups",
    "attributes": {
      "name": "External Beta Testers",
      "hasAccessToAllBuilds": true,
      "feedbackEnabled": true,
      "publicLinkEnabled": true,
      "publicLinkLimit": 100
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

### Update a Beta Group

更新 Beta 测试组信息。

```
PATCH /v1/betaGroups/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "betaGroups",
    "id": "group-123",
    "attributes": {
      "feedbackEnabled": false,
      "publicLinkEnabled": false
    }
  }
}
```

### Delete a Beta Group

删除 Beta 测试组。

```
DELETE /v1/betaGroups/{id}
```

### Add Beta Testers to Group

向 Beta 组添加测试人员。

```
POST /v1/betaGroups/{id}/relationships/betaTesters
```

#### Request Body

```json
{
  "data": [
    {
      "type": "betaTesters",
      "id": "tester-123"
    },
    {
      "type": "betaTesters",
      "id": "tester-456"
    }
  ]
}
```

### Add Build to Beta Group

向 Beta 组添加构建版本。

```
POST /v1/betaGroups/{id}/relationships/builds
```

#### Request Body

```json
{
  "data": [
    {
      "type": "builds",
      "id": "build-123"
    }
  ]
}
```

## Object Schema

```json
{
  "type": "betaGroups",
  "id": "string",
  "attributes": {
    "name": "string",
    "isInternalGroup": "boolean",
    "publicLinkEnabled": "boolean",
    "publicLinkId": "string",
    "publicLinkLimit": "integer",
    "publicLink": "string",
    "feedbackEnabled": "boolean",
    "hasAccessToAllBuilds": "boolean",
    "createdDate": "string"
  },
  "relationships": {
    "app": "object",
    "builds": "object",
    "betaTesters": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | 组名称 |
| `isInternalGroup` | boolean | 是否为内部组 |
| `publicLinkEnabled` | boolean | 是否启用公共链接 |
| `publicLinkId` | string | 公共链接 ID |
| `publicLinkLimit` | integer | 公共链接人数限制 |
| `publicLink` | string | 公共链接 URL |
| `feedbackEnabled` | boolean | 是否启用反馈 |
| `hasAccessToAllBuilds` | boolean | 是否可访问所有构建 |
| `createdDate` | string | 创建日期 |

## Internal vs External Groups

### Internal Groups
- 仅限团队成员
- 自动获得最新构建
- 不需要审核
- 每个应用最多一个内部组

### External Groups
- 外部测试人员（最多 10000 人）
- 需要通过 Beta 审核
- 可启用公共链接
- 可设置访问权限

## Related Documentation

- [Beta Testers API](beta_testers.md)
- [Builds API](builds.md)
- [Apps API](apps.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Beta Groups - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/beta_groups)
