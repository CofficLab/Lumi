# User Invitations API

管理 App Store Connect 团队成员邀请。

## Resource Information

- **Type**: `userInvitations`
- **Base Path**: `/v1/userInvitations`

## Endpoints

### List Invitations

获取待处理的邀请列表。

```
GET /v1/userInvitations
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[email]` | string[] | No | 按邮箱过滤 |
| `filter[roles]` | string[] | No | 按角色过滤 |
| `sort` | string | No | 排序字段：`email`, `-email`, `lastName`, `-lastName` |
| `fields[userInvitations]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "userInvitations",
      "id": "invite-123",
      "attributes": {
        "email": "jane.smith@example.com",
        "firstName": "Jane",
        "lastName": "Smith",
        "roles": [
          "DEVELOPER"
        ],
        "allAppsVisible": true,
        "provisioningAllowed": true,
        "expirationDate": "2024-02-15T10:30:00.000+00:00"
      },
      "relationships": {
        "visibleApps": {
          "links": {
            "self": "/v1/userInvitations/invite-123/relationships/visibleApps",
            "related": "/v1/userInvitations/invite-123/visibleApps"
          }
        }
      },
      "links": {
        "self": "/v1/userInvitations/invite-123"
      }
    }
  ]
}
```

### Read Invitation

获取特定邀请的信息。

```
GET /v1/userInvitations/{id}
```

### Invite User

邀请新成员加入团队。

```
POST /v1/userInvitations
```

#### Request Body

```json
{
  "data": {
    "type": "userInvitations",
    "attributes": {
      "email": "jane.smith@example.com",
      "firstName": "Jane",
      "lastName": "Smith",
      "roles": [
        "DEVELOPER",
        "MARKETING"
      ],
      "allAppsVisible": false,
      "provisioningAllowed": true
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

#### Response

```json
{
  "data": {
    "type": "userInvitations",
    "id": "invite-456",
    "attributes": {
      "email": "jane.smith@example.com",
      "firstName": "Jane",
      "lastName": "Smith",
      "roles": [
        "DEVELOPER",
        "MARKETING"
      ],
      "expirationDate": "2024-02-15T10:30:00.000+00:00"
    }
  }
}
```

### Cancel Invitation

取消待处理的邀请。

```
DELETE /v1/userInvitations/{id}
```

#### Response

```
HTTP/1.1 204 No Content
```

## Object Schema

```json
{
  "type": "userInvitations",
  "id": "string",
  "attributes": {
    "email": "string",
    "firstName": "string",
    "lastName": "string",
    "roles": ["string"],
    "allAppsVisible": "boolean",
    "provisioningAllowed": "boolean",
    "expirationDate": "string"
  },
  "relationships": {
    "visibleApps": "object"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `email` | string | 被邀请人的邮箱 |
| `firstName` | string | 名字 |
| `lastName` | string | 姓氏 |
| `roles` | array | 角色列表 |
| `allAppsVisible` | boolean | 是否可见所有应用 |
| `provisioningAllowed` | boolean | 是否允许配置 |
| `expirationDate` | string | 邀请过期时间 |

## Invitation Lifecycle

```
Created (POST)
    ↓
Email Sent
    ↓
Accepted → User Created
    ↓
OR
Expired → Removed
    ↓
OR
Cancelled (DELETE) → Removed
```

## Notes

- 邀请有效期为 30 天
- 过期后需要重新邀请
- 只能取消待处理的邀请
- 已接受的邀请会转为用户记录

## Related Documentation

- [Users API](users.md)
- [Apps API](apps.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [User Invitations - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/user_invitations)
