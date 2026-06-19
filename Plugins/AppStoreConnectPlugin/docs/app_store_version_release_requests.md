# App Store Version Release Requests API

App Store Version Release Requests 资源用于将已审核通过、处于「等待开发者发布」（`PENDING_DEVELOPER_RELEASE`）状态的版本手动发布到 App Store。

## Resource Information

- **Type**: `appStoreVersionReleaseRequests`
- **Base Path**: `/v1/appStoreVersionReleaseRequests`

## 适用场景

当版本在提交审核时选择了 **手动发布**（`releaseType: MANUAL`），审核通过后版本状态会变为 `PENDING_DEVELOPER_RELEASE`（App Store Connect 界面显示为「等待开发者发布」）。此时需要调用本 API 或于 App Store Connect 中点击「发布此版本」来完成上架。

> **注意**：仅当版本处于 `PENDING_DEVELOPER_RELEASE` 状态时可调用。发送请求前请确认已准备好发布——**该请求无法通过 API 取消**（与 App Store Connect 网页端在发布后短时间内可「取消发布」的行为不同）。

## Endpoints

### Manually Release an App Store Approved Version

手动发布已审核通过的版本。

```
POST /v1/appStoreVersionReleaseRequests
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersionReleaseRequests",
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
    "type": "appStoreVersionReleaseRequests",
    "id": "release-request-123",
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

## Workflow

### 手动发布完整流程

1. **创建版本并设置手动发布**
   ```
   POST /v1/appStoreVersions
   ```
   请求体中设置 `"releaseType": "MANUAL"`。

2. **配置元数据、选择 Build、提交审核**
   - 参见 [App Store Version Submissions API](app_store_version_submissions.md)

3. **等待审核通过**
   - 审核中：`IN_REVIEW`
   - 审核通过且为手动发布：`PENDING_DEVELOPER_RELEASE`

4. **手动发布**
   ```
   POST /v1/appStoreVersionReleaseRequests
   ```
   将 `appStoreVersion` 关联到目标版本 ID。

5. **发布后状态变化**
   - `PROCESSING_FOR_DISTRIBUTION` → `READY_FOR_SALE`
   - 版本在 App Store 上可见可能需要最多 24 小时

### 与分阶段发布的关系

若版本已配置 [分阶段发布](app_store_version_phased_releases.md) 且状态为 `INACTIVE`：

- 调用本 API 会**启动分阶段发布**，而非一次性 100% 发布
- 发布启动后，可通过 `PATCH /v1/appStoreVersionPhasedReleases/{id}` 暂停、恢复或完成

若未启用分阶段发布，则调用本 API 会将版本完整发布到 App Store。

## Prerequisites

发布前请确认：

- ✅ 版本 `appStoreState` 为 `PENDING_DEVELOPER_RELEASE`
- ✅ 版本 `releaseType` 为 `MANUAL`
- ✅ 出口合规、加密声明等审核要求已满足
- ✅ 各平台版本需分别发布（iOS、macOS、tvOS 等各自独立）

可通过以下接口确认当前状态：

```
GET /v1/appStoreVersions/{id}?fields[appStoreVersions]=appStoreState,releaseType,versionString
```

## Object Schema

### App Store Version Release Request Object

```json
{
  "type": "appStoreVersionReleaseRequests",
  "id": "string",
  "relationships": {
    "appStoreVersion": {
      "data": {
        "type": "appStoreVersions",
        "id": "string"
      }
    }
  }
}
```

## State Transitions

```
PREPARE_FOR_SUBMISSION
    ↓ (POST appStoreVersionSubmissions)
WAITING_FOR_REVIEW
    ↓
IN_REVIEW
    ↓ (approved, releaseType = MANUAL)
PENDING_DEVELOPER_RELEASE
    ↓ (POST appStoreVersionReleaseRequests)
PROCESSING_FOR_DISTRIBUTION
    ↓
READY_FOR_SALE
```

若 `releaseType` 为 `AFTER_APPROVAL`，审核通过后会跳过 `PENDING_DEVELOPER_RELEASE`，直接进入分发流程。

## Error Responses

### 409 Conflict

版本当前状态不允许发布（例如尚未审核通过，或已处于销售中）。

```json
{
  "errors": [
    {
      "status": "409",
      "code": "STATE_ERROR",
      "title": "The request cannot be fulfilled because of the state of another resource.",
      "detail": "The app store version is not in a valid state for this operation"
    }
  ]
}
```

### 422 Unprocessable Entity

请求体缺少必填字段或版本 ID 无效。

## Related Documentation

- [App Store Versions API](app_store_versions.md) - 版本状态与 `releaseType`
- [App Store Version Submissions API](app_store_version_submissions.md) - 提交审核
- [App Store Version Phased Releases API](app_store_version_phased_releases.md) - 分阶段发布
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [App Store Version Release Requests - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_store_version_release_requests)
- [Manually Release an App Store Approved Version of Your App](https://developer.apple.com/documentation/appstoreconnectapi/manually_release_an_app_store_approved_version_of_your_app)
- [Select an App Store Version Release Option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)
