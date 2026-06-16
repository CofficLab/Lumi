# Beta Testers API

管理 TestFlight 的 Beta 测试人员。

## Resource Information

- **Type**: `betaTesters`
- **Base Path**: `/v1/betaTesters`

## Endpoints

### List Beta Testers

获取 Beta 测试人员列表。

```
GET /v1/betaTesters
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[firstName]` | string[] | No | 按名字过滤 |
| `filter[lastName]` | string[] | No | 按姓氏过滤 |
| `filter[email]` | string[] | No | 按邮箱过滤 |
| `filter[inviteType]` | string[] | No | 按邀请类型过滤：`EMAIL`, `PUBLIC_LINK` |
| `filter[apps]` | string[] | No | 按应用 ID 过滤 |
| `filter[betaGroups]` | string[] | No | 按 Beta 组 ID 过滤 |
| `filter[builds]` | string[] | No | 按构建 ID 过滤 |
| `sort` | string | No | 排序字段：`email`, `-email`, `firstName`, `-firstName`, `lastName`, `-lastName`, `inviteType`, `-inviteType` |
| `fields[betaTesters]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "betaTesters",
      "id": "tester-123",
      "attributes": {
        "firstName": "John",
        "lastName": "Doe",
        "email": "john.doe@example.com",
        "inviteType": "EMAIL",
        "lastModifiedDate": "2024-01-15T10:30:00.000+00:00"
      },
      "relationships": {
        "apps": {
          "links": {
            "self": "/v1/betaTesters/tester-123/relationships/apps",
            "related": "/v1/betaTesters/tester-123/apps"
          }
        },
        "betaGroups": {
          "links": {
            "self": "/v1/betaTesters/tester-123/relationships/betaGroups",
            "related": "/v1/betaTesters/tester-123/betaGroups"
          }
        },
        "builds": {
          "links": {
            "self": "/v1/betaTesters/tester-123/relationships/builds",
            "related": "/v1/betaTesters/tester-123/builds"
          }
        }
      },
      "links": {
        "self": "/v1/betaTesters/tester-123"
      }
    }
  ]
}
```

### Read Beta Tester

获取特定 Beta 测试人员的信息。

```
GET /v1/betaTesters/{id}
```

### Invite a Beta Tester

邀请新的 Beta 测试人员。

```
POST /v1/betaTesters
```

#### Request Body

```json
{
  "data": {
    "type": "betaTesters",
    "attributes": {
      "firstName": "Jane",
      "lastName": "Smith",
      "email": "jane.smith@example.com"
    },
    "relationships": {
      "betaGroups": {
        "data": [
          {
            "type": "betaGroups",
            "id": "group-123"
          }
        ]
      }
    }
  }
}
```

### Remove a Beta Tester

移除 Beta 测试人员。

```
DELETE /v1/betaTesters/{id}
```

### Remove Beta Tester from Beta Groups

将测试人员从 Beta 组中移除。

```
DELETE /v1/betaTesters/{id}/relationships/betaGroups
```

#### Request Body

```json
{
  "data": [
    {
      "type": "betaGroups",
      "id": "group-123"
    }
  ]
}
```

### Remove Beta Tester from Builds

移除测试人员对特定构建的访问权限。

```
DELETE /v1/betaTesters/{id}/relationships/builds
```

## Object Schema

```json
{
  "type": "betaTesters",
  "id": "string",
  "attributes": {
    "firstName": "string",
    "lastName": "string",
    "email": "string",
    "inviteType": "string",
    "lastModifiedDate": "string"
  },
  "relationships": {
    "apps": "object",
    "betaGroups": "object",
    "builds": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `firstName` | string | 名字 |
| `lastName` | string | 姓氏 |
| `email` | string | 邮箱地址 |
| `inviteType` | string | 邀请类型：`EMAIL`, `PUBLIC_LINK` |
| `lastModifiedDate` | string | 最后修改日期 |

## Related Documentation

- [Beta Groups API](beta_groups.md)
- [Builds API](builds.md)
- [Apps API](apps.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Beta Testers - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/beta_testers)
