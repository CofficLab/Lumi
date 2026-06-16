# Users API

管理 App Store Connect 团队成员和权限。

## Resource Information

- **Type**: `users`
- **Base Path**: `/v1/users`

## Endpoints

### List Users

获取团队成员列表。

```
GET /v1/users
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[username]` | string[] | No | 按用户名过滤 |
| `filter[roles]` | string[] | No | 按角色过滤 |
| `filter[visibleApps]` | string[] | No | 按可见应用过滤 |
| `sort` | string | No | 排序字段：`username`, `-username`, `lastName`, `-lastName` |
| `fields[users]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "users",
      "id": "user-123",
      "attributes": {
        "username": "john.doe@example.com",
        "firstName": "John",
        "lastName": "Doe",
        "roles": [
          "ADMIN",
          "DEVELOPER"
        ],
        "allAppsVisible": true,
        "provisioningAllowed": true,
        "lastLogin": "2024-01-15T10:30:00.000+00:00"
      },
      "relationships": {
        "visibleApps": {
          "links": {
            "self": "/v1/users/user-123/relationships/visibleApps",
            "related": "/v1/users/user-123/visibleApps"
          }
        }
      },
      "links": {
        "self": "/v1/users/user-123"
      }
    }
  ]
}
```

### Read User

获取特定用户的信息。

```
GET /v1/users/{id}
```

### Update User

更新用户信息和权限。

```
PATCH /v1/users/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "users",
    "id": "user-123",
    "attributes": {
      "roles": [
        "DEVELOPER"
      ],
      "allAppsVisible": false
    },
    "relationships": {
      "visibleApps": {
        "data": [
          {
            "type": "apps",
            "id": "123456789"
          }
        ]
      }
    }
  }
}
```

### Remove User

移除团队成员。

```
DELETE /v1/users/{id}
```

### Update User's Visible Apps

更新用户可见的应用列表。

```
PATCH /v1/users/{id}/relationships/visibleApps
```

#### Request Body

```json
{
  "data": [
    {
      "type": "apps",
      "id": "123456789"
    },
    {
      "type": "apps",
      "id": "987654321"
    }
  ]
}
```

## Object Schema

```json
{
  "type": "users",
  "id": "string",
  "attributes": {
    "username": "string",
    "firstName": "string",
    "lastName": "string",
    "roles": ["string"],
    "allAppsVisible": "boolean",
    "provisioningAllowed": "boolean",
    "lastLogin": "string"
  },
  "relationships": {
    "visibleApps": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `username` | string | 用户名（邮箱） |
| `firstName` | string | 名字 |
| `lastName` | string | 姓氏 |
| `roles` | array | 角色列表 |
| `allAppsVisible` | boolean | 是否可见所有应用 |
| `provisioningAllowed` | boolean | 是否允许配置 |
| `lastLogin` | string | 最后登录时间 |

## Roles

| Role | Description |
|------|-------------|
| `ADMIN` | 管理员，完全访问权限 |
| `DEVELOPER` | 开发者，可创建和编辑应用 |
| `MARKETING` | 营销人员，可管理 App Store 信息 |
| `SALES` | 销售人员，可访问销售报告 |
| `FINANCE` | 财务人员，可访问财务报告 |
| `ACCESS_TO_REPORTS` | 可访问报告 |
| `CUSTOMER_SUPPORT` | 客户支持 |
| `IMAGE_MANAGER` | 图片管理器 |
| `ACCOUNT_HOLDER` | 账户持有人 |
| `READ_ONLY` | 只读访问 |
| `TECHNICAL` | 技术人员 |

## Related Documentation

- [User Invitations API](user_invitations.md)
- [Apps API](apps.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Users - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/users)
