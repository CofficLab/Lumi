# App Store Version Phased Releases API

分阶段发布允许在 7 天内逐步向用户发布应用更新。

## Resource Information

- **Type**: `appStoreVersionPhasedReleases`
- **Base Path**: `/v1/appStoreVersionPhasedReleases`

## Endpoints

### Create a Phased Release

为 App Store 版本创建分阶段发布。

```
POST /v1/appStoreVersionPhasedReleases
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersionPhasedReleases",
    "attributes": {
      "phasedReleaseState": "INACTIVE"
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

#### Response

```json
{
  "data": {
    "type": "appStoreVersionPhasedReleases",
    "id": "phased-release-123",
    "attributes": {
      "phasedReleaseState": "INACTIVE",
      "startDate": null,
      "totalPauseDuration": 0,
      "currentDayNumber": 0
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

### Read Phased Release Information

获取分阶段发布的信息。

```
GET /v1/appStoreVersionPhasedReleases/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | 分阶段发布 ID |

### Update Phased Release State

更新分阶段发布的状态（暂停、恢复、完成）。

```
PATCH /v1/appStoreVersionPhasedReleases/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersionPhasedReleases",
    "id": "phased-release-123",
    "attributes": {
      "phasedReleaseState": "ACTIVE"
    }
  }
}
```

### Delete a Phased Release

删除分阶段发布。

```
DELETE /v1/appStoreVersionPhasedReleases/{id}
```

## Phased Release States

| State | Description |
|-------|-------------|
| `INACTIVE` | 未激活，尚未开始 |
| `ACTIVE` | 正在进行分阶段发布 |
| `PAUSED` | 已暂停 |
| `COMPLETE` | 已完成全部 7 天发布 |

## Phased Release Schedule

分阶段发布按照以下百分比逐步发布：

| Day | Percentage |
|-----|------------|
| 1 | 1% |
| 2 | 2% |
| 3 | 5% |
| 4 | 10% |
| 5 | 20% |
| 6 | 50% |
| 7 | 100% |

## Object Schema

```json
{
  "type": "appStoreVersionPhasedReleases",
  "id": "string",
  "attributes": {
    "phasedReleaseState": "string",
    "startDate": "string|null",
    "totalPauseDuration": "integer",
    "currentDayNumber": "integer"
  },
  "relationships": {
    "appStoreVersion": "object"
  }
}
```

## Related Documentation

- [App Store Versions API](app_store_versions.md)
- [App Store Version Release Requests API](app_store_version_release_requests.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [App Store Version Phased Releases - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_store_version_phased_releases)
