# App Store Version Submissions API

App Store Version Submissions 资源用于将 App Store 版本提交给 Apple 审核。

## Resource Information

- **Type**: `appStoreVersionSubmissions`
- **Base Path**: `/v1/appStoreVersionSubmissions`

## Endpoints

### Submit for Review

将 App Store 版本提交给 Apple 审核。

```
POST /v1/appStoreVersionSubmissions
```

#### Request Body

```json
{
  "data": {
    "type": "appStoreVersionSubmissions",
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
    "type": "appStoreVersionSubmissions",
    "id": "submission-123",
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

### Delete a Submission

删除待审核的版本提交（撤回提交）。

```
DELETE /v1/appStoreVersionSubmissions/{id}
```

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | 提交 ID |

#### Response

```
HTTP/1.1 204 No Content
```

## Workflow

### Complete Submission Workflow

1. **创建 App Store 版本**
   ```
   POST /v1/appStoreVersions
   ```

2. **设置版本元数据**（可选）
   - 设置版本说明
   - 上传截图
   - 设置关键词

3. **选择 Build**
   ```
   PATCH /v1/appStoreVersions/{id}
   {
     "data": {
       "attributes": {
         "build": {
           "data": {
             "type": "builds",
             "id": "build-123"
           }
         }
       }
     }
   }
   ```

4. **提交审核**
   ```
   POST /v1/appStoreVersionSubmissions
   ```

5. **等待审核**
   - 状态变为 `WAITING_FOR_REVIEW`
   - 然后变为 `IN_REVIEW`

6. **审核结果**
   - `releaseType: AFTER_APPROVAL` → 自动进入分发，最终 `READY_FOR_SALE`
   - `releaseType: MANUAL` → `PENDING_DEVELOPER_RELEASE`，需调用 [Release Requests API](app_store_version_release_requests.md) 手动发布
   - `REJECTED` - 审核被拒绝

### Cancel a Submission

如果版本还在 `WAITING_FOR_REVIEW` 状态，可以撤回提交：

```
DELETE /v1/appStoreVersionSubmissions/{submissionId}
```

## Object Schema

### App Store Version Submission Object

```json
{
  "type": "appStoreVersionSubmissions",
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

## Common Issues

### Missing Required Information

提交前确保：
- ✅ 已选择 Build
- ✅ 已设置版本号
- ✅ 已填写必要的元数据
- ✅ 已上传截图（如需要）
- ✅ 已设置隐私政策 URL（如需要）

### Export Compliance

某些应用需要声明出口合规信息：
- 使用加密技术
- 需要回答加密相关问题
- 可能需要提供加密合规文档

### IDFA Declaration

如果应用使用 IDFA（广告标识符）：
- 需要声明使用 IDFA
- 说明使用目的
- 提供隐私政策说明

## Error Responses

### 409 Conflict

```json
{
  "errors": [
    {
      "status": "409",
      "code": "SUBMISSION_IN_PROGRESS",
      "title": "A submission is already in progress",
      "detail": "The app store version already has a pending submission"
    }
  ]
}
```

### 422 Unprocessable Entity

```json
{
  "errors": [
    {
      "status": "422",
      "code": "MISSING_REQUIRED_FIELD",
      "title": "A required field is missing",
      "detail": "The 'build' field is required before submission"
    }
  ]
}
```

## State Transitions

```
PREPARE_FOR_SUBMISSION
    ↓ (POST submission)
WAITING_FOR_REVIEW
    ↓ (Apple picks up)
IN_REVIEW
    ↓ (review complete, releaseType = AFTER_APPROVAL)
PROCESSING_FOR_DISTRIBUTION → READY_FOR_SALE
    ↓ (review complete, releaseType = MANUAL)
PENDING_DEVELOPER_RELEASE
    ↓ (POST appStoreVersionReleaseRequests)
PROCESSING_FOR_DISTRIBUTION → READY_FOR_SALE
    ↓ (rejected)
REJECTED
```

## Related Documentation

- [App Store Versions API](app_store_versions.md)
- [App Store Version Release Requests API](app_store_version_release_requests.md)
- [Builds API](builds.md)
- [App Store Version Localizations API](app_store_version_localizations.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [App Store Version Submissions - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_store_version_submissions)
