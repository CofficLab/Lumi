# App Store Connect API 端点参考

> 本文件是 SKILL.md 的配套参考：列出本插件已知并验证过的 App Store Connect REST API 端点、调用参数和使用方式。
> 需要用 curl 调试或探测时（见 SKILL.md「直接用 curl 调试」），按本表选择端点。完整端点目录以 [Apple 官方文档](https://developer.apple.com/documentation/appstoreconnectapi)为准。
>
> 认证方式：`Authorization: Bearer <JWT>`（JWT 生成方法见 SKILL.md）。Base URL：`https://api.appstoreconnect.apple.com`。
> 请求/响应为 JSON:API 格式（`{"data": {...}}` / `{"data": [...]}`），日期为 ISO 8601。

---

## 通用查询参数

| 参数 | 说明 |
|------|------|
| `limit` | 分页大小，单页上限 200 |
| `sort` | 排序，`-` 前缀倒序，如 `-uploadedDate` |
| `filter[xxx]` | 过滤，如 `filter[app]`、`filter[name]` |
| `include` | 展开 relationships，如 `include=app` |
| `fields[资源名]` | 稀疏字段集，只返回指定属性 |
| `limit[关联名]` | 限制 included 关联数量，如 `limit[appScreenshots]=10` |

**已知怪癖（实测）**：

- `GET /v1/appStoreVersions/{id}` 带 `fields[appStoreVersions]=...` + `include=app` 时，Apple 会清空 `data.relationships`（included 仍在）。瘦身材用 `fields[apps]=name`，并从 `included` 数组按 `type` 兜底匹配。
- `GET /v1/appScreenshotSets/{id}` 带 `fields[...]` 时同样清空 `relationships.appScreenshots.data` 指针。该端点不要带 `fields`。
- 错误明细在 `errors[].detail` / `errors[].meta.associatedErrors`，比顶层 `errors[].title` 完整。

---

## 1. Apps

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/apps` | 列出应用 | `app_store_connect_list_apps` |
| GET | `/v1/apps/{id}/appInfos` | 列出应用的 AppInfo（年龄分级入口） | `app_store_connect_set_age_rating` 内部 |
| GET | `/v1/apps/{id}/reviewSubmissions` | 列出应用的审核提交 | `app_store_connect_submit_version` 内部 |

### GET /v1/apps

```
/v1/apps?limit=100&sort=name&fields[apps]=name,bundleId,sku,primaryLocale,appStoreIcon&include=appStoreIcon&fields[buildIcons]=iconAsset
```

- `filter[name]=xxx`：按名称筛选（搜索）。
- `include=appStoreIcon` + `fields[buildIcons]=iconAsset`：取图标 URL。

### GET /v1/apps/{id}/appInfos

```
/v1/apps/{id}/appInfos?limit=50&fields[appInfos]=appStoreState,state
```

- `state` 是当前枚举，`appStoreState` 是旧枚举（API 3.3 起废弃），优先用 `state`。
- 可编辑状态：`PREPARE_FOR_SUBMISSION`、`DEVELOPER_REJECTED`、`REJECTED`、`WAITING_FOR_REVIEW`。

---

## 2. App Store 版本

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/apps/{id}/appStoreVersions` | 列出版本 | `app_store_connect_list_versions` |
| GET | `/v1/appStoreVersions/{id}` | 读版本详情 | `app_store_connect_read_version` |
| POST | `/v1/appStoreVersions` | 创建版本 | `app_store_connect_create_version` |
| PATCH | `/v1/appStoreVersions/{id}` | 更新版本属性 | `app_store_connect_update_version` |
| DELETE | `/v1/appStoreVersions/{id}` | 删除版本（危险） | `app_store_connect_delete_version` |
| GET | `/v1/appStoreVersions/{id}/relationships/build` | 读已关联 build | `app_store_connect_assign_build` 内部 |
| PATCH | `/v1/appStoreVersions/{id}/relationships/build` | 关联 build | `app_store_connect_assign_build` |
| GET | `/v1/appStoreVersions/{id}/appStoreVersionLocalizations` | 列出本地化 | `app_store_connect_list_localizations` |
| GET | `/v1/appStoreVersions/{id}/appStoreReviewDetail` | 读审核联系信息 | 排查用（见 §7） |

### GET（列出/读取）常用字段

```
fields[appStoreVersions]=platform,versionString,appStoreState,appVersionState,createdDate,copyright,releaseType,downloadable,earliestReleaseDate
```

平台值：`IOS`、`MAC_OS`、`TV_OS`、`VISION_OS`。版本号创建后不可修改。

### POST /v1/appStoreVersions（创建）

```json
{
  "data": {
    "type": "appStoreVersions",
    "attributes": {
      "versionString": "1.2.0",
      "platform": "IOS",
      "releaseType": "AFTER_APPROVAL"
    },
    "relationships": {
      "app": { "data": { "type": "apps", "id": "<appID>" } }
    }
  }
}
```

- `releaseType`：`AFTER_APPROVAL` / `MANUAL` / `SCHEDULED`（`SCHEDULED` 需配 `earliestReleaseDate`）。

### PATCH /v1/appStoreVersions/{id}（更新）

```json
{
  "data": {
    "type": "appStoreVersions",
    "id": "<versionID>",
    "attributes": {
      "copyright": "© 2026 Your Company",
      "releaseType": "MANUAL",
      "downloadable": true,
      "earliestReleaseDate": null
    }
  }
}
```

- 只发送要改的字段；`earliestReleaseDate` 传 `null` 取消预定发布时间。

### PATCH relationships/build（关联构建）

```json
{ "data": { "type": "builds", "id": "<buildID>" } }
```

- 返回 204 无响应体。未关联时 GET 该 relationships 返回 `{"data": null}`。

---

## 3. 商店元数据（本地化）

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/appStoreVersionLocalizations/{id}` | 读完整元数据 | `app_store_connect_read_localization` |
| POST | `/v1/appStoreVersionLocalizations` | 创建本地化 | `app_store_connect_create_localization` |
| PATCH | `/v1/appStoreVersionLocalizations/{id}` | 更新元数据 | `app_store_connect_update_localization` |

### 字段

| 属性 | 说明 | 约束 |
|------|------|------|
| `locale` | 如 `en-US`、`zh-Hans` | 创建后不可改 |
| `description` | 描述 | ≤ 4000 字符 |
| `keywords` | 关键词 | ≤ 100 字符，逗号分隔 |
| `promotionalText` | 推广文本 | ≤ 170 字符 |
| `whatsNew` | 更新说明 | ≤ 4000 字符 |
| `supportUrl` | 支持 URL | 必须是合法 RFC 3986 URI |
| `marketingUrl` | 营销 URL | 必须是合法 RFC 3986 URI |

### POST（创建）

```json
{
  "data": {
    "type": "appStoreVersionLocalizations",
    "attributes": {
      "locale": "zh-Hans",
      "description": "…",
      "keywords": "…",
      "promotionalText": "…",
      "whatsNew": "…",
      "supportUrl": "https://example.com/support"
    },
    "relationships": {
      "appStoreVersion": { "data": { "type": "appStoreVersions", "id": "<versionID>" } }
    }
  }
}
```

### PATCH（更新）

- 只发送要改的字段（部分更新）。
- URL 字段传空串会被拒（非法 URI）；要清空 URL 传 `null`。创建时 URL 为空则整个省略。

---

## 4. 截图

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/appStoreVersionLocalizations/{id}/relationships/appScreenshotSets` | 列出截图集 ID | `app_store_connect_list_screenshot_sets` |
| GET | `/v1/appScreenshotSets/{id}` | 读截图集（含 included 截图） | 同上 |
| POST | `/v1/appScreenshotSets` | 创建截图集 | `app_store_connect_create_screenshot_set` |
| DELETE | `/v1/appScreenshotSets/{id}` | 删除截图集 | — |
| GET | `/v1/appScreenshotSets/{id}/appScreenshots` | 列出截图 | `app_store_connect_list_screenshots` |
| GET | `/v1/appScreenshots` | 列出截图（filter 方式） | 同上（兜底） |
| POST | `/v1/appScreenshots` | 预约上传 | `app_store_connect_upload_screenshot` |
| PATCH | `/v1/appScreenshots/{id}` | 确认上传完成 | 同上 |
| DELETE | `/v1/appScreenshots/{id}` | 删除截图 | `app_store_connect_delete_screenshot` |

> 注意：部分账号对 `GET /v1/appScreenshotSets` 集合查询返回权限错误（GET_COLLECTION 被拒）。稳妥路径是先走 `relationships/appScreenshotSets` 拿 ID，再逐个 GET_INSTANCE。

### POST /v1/appScreenshotSets（创建）

```json
{
  "data": {
    "type": "appScreenshotSets",
    "attributes": { "screenshotDisplayType": "APP_IPHONE_67" },
    "relationships": {
      "appStoreVersionLocalization": { "data": { "type": "appStoreVersionLocalizations", "id": "<localizationID>" } }
    }
  }
}
```

常见 `screenshotDisplayType`（iOS）：`APP_IPHONE_67`、`APP_IPHONE_65`、`APP_IPHONE_61`、`APP_IPHONE_58`、`APP_IPAD_PRO_129` 等。

### 截图上传三步（resumable upload）

**① 预约** `POST /v1/appScreenshots`：

```json
{
  "data": {
    "type": "appScreenshots",
    "attributes": { "fileName": "home.png", "fileSize": 123456 },
    "relationships": {
      "appScreenshotSet": { "data": { "type": "appScreenshotSets", "id": "<setID>" } }
    }
  }
}
```

响应 `data.attributes.uploadOperations` 给出预签名分片上传指令：`method`、`url`、`offset`、`length`、`requestHeaders`。

**② 分片 PUT**：对每个 operation 按 `offset/length` 切片，用 operation 自带的 `method` 和 `requestHeaders` 上传到 `url`。**不带 Authorization 头**（预签名 URL）。

**③ 确认** `PATCH /v1/appScreenshots/{id}`：

```json
{
  "data": {
    "type": "appScreenshots",
    "id": "<screenshotID>",
    "attributes": {
      "sourceFileChecksum": "<整个文件的 MD5 十六进制小写>",
      "uploaded": true
    }
  }
}
```

---

## 5. 构建

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/builds` | 列出构建 | `app_store_connect_list_builds` |
| PATCH | `/v1/builds/{id}` | 更新出口合规声明 | `app_store_connect_assign_build` 内部 |

### GET /v1/builds

```
/v1/builds?filter[app]=<appID>&filter[preReleaseVersion.platform]=IOS&filter[expired]=false&sort=-uploadedDate&limit=50&fields[builds]=version,uploadedDate,processingState,expired,usesNonExemptEncryption&include=preReleaseVersion&fields[preReleaseVersions]=version,platform
```

- `filter[expired]=false` 排除过期构建。
- `processingState` 为 `VALID` 才可关联到版本。

### PATCH /v1/builds/{id}（出口合规）

```json
{
  "data": {
    "type": "builds",
    "id": "<buildID>",
    "attributes": { "usesNonExemptEncryption": false }
  }
}
```

---

## 6. 审核提交（Review Submissions，API 1.7+）

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| POST | `/v1/reviewSubmissions` | 创建提交 | `app_store_connect_submit_version` |
| POST | `/v1/reviewSubmissionItems` | 把版本加入提交 | 同上 |
| PATCH | `/v1/reviewSubmissions/{id}` | 提交 / 撤回 | `app_store_connect_submit_version` / `app_store_connect_withdraw_submission` |
| GET | `/v1/reviewSubmissions/{id}/items` | 列出提交条目 | 排查用 |

> **旧资源已废弃**：`POST /v1/appStoreVersionSubmissions` 返回 403（仅允许 DELETE）；`GET /v1/appStoreVersions/{id}/relationships/appStoreVersionSubmission` 返回 404。查询某版本是否在途：列 `apps/{id}/reviewSubmissions`，逐个查 items 是否包含该版本。

### 提交流程（三步）

**① 创建提交** `POST /v1/reviewSubmissions`：

```json
{
  "data": {
    "type": "reviewSubmissions",
    "relationships": {
      "app": { "data": { "type": "apps", "id": "<appID>" } }
    }
  }
}
```

**② 加入版本** `POST /v1/reviewSubmissionItems`（服务器在此校验审核联系人、构建等，失败返回 409 + `associatedErrors` 明细）：

```json
{
  "data": {
    "type": "reviewSubmissionItems",
    "relationships": {
      "reviewSubmission": { "data": { "type": "reviewSubmissions", "id": "<submissionID>" } },
      "appStoreVersion": { "data": { "type": "appStoreVersions", "id": "<versionID>" } }
    }
  }
}
```

**③ 触发提交** `PATCH /v1/reviewSubmissions/{id}`：

```json
{ "data": { "type": "reviewSubmissions", "id": "<submissionID>", "attributes": { "submitted": true } } }
```

**撤回**：同上，`"canceled": true`。

### 在途状态

`READY_FOR_REVIEW`、`WAITING_FOR_REVIEW`、`IN_REVIEW`、`UNRESOLVED_ISSUES`、`COMPLETING` 算在途；`COMPLETE`、`CANCELING` 是终态。

---

## 7. 发布与审核信息

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| POST | `/v1/appStoreVersionReleaseRequests` | 发布待开发者发布的版本 | `app_store_connect_release_version` |
| GET | `/v1/appStoreVersions/{id}/appStoreReviewDetail` | 读审核联系信息 | 排查用 |
| PATCH | `/v1/appStoreReviewDetails/{id}` | 补全审核联系信息 | 排查用 |

### POST /v1/appStoreVersionReleaseRequests

```json
{
  "data": {
    "type": "appStoreVersionReleaseRequests",
    "relationships": {
      "appStoreVersion": { "data": { "type": "appStoreVersions", "id": "<versionID>" } }
    }
  }
}
```

### 审核联系信息（提交前必查）

首次提交若联系信息缺失，409 明细列出 `appStoreReviewDetails` 缺失字段。补全 PATCH：

```json
{
  "data": {
    "type": "appStoreReviewDetails",
    "id": "<reviewDetailID>",
    "attributes": {
      "contactFirstName": "…",
      "contactLastName": "…",
      "contactEmail": "…",
      "contactPhone": "+8613800138000"
    }
  }
}
```

电话必须带 `+` 国家码。

---

## 8. 年龄分级

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/appInfos/{id}/ageRatingDeclaration` | 读年龄分级声明 | `app_store_connect_set_age_rating` 内部 |
| PATCH | `/v1/ageRatingDeclarations/{id}` | 更新年龄分级 | `app_store_connect_set_age_rating` |

> 年龄分级声明是 **app 级**资源（挂在 `AppInfo` 上），所有版本共享。版本级端点（`/v1/appStoreVersions/{id}/ageRatingDeclaration`）已在 API 4.3 移除。
> **没有 create 端点**：首次声明必须在 App Store Connect 网站完成问卷（App Information → Age Ratings → Save），之后 API 读写才可用。

读取路径：`GET /v1/apps/{id}/appInfos` 挑 appInfo（可编辑优先）→ `GET /v1/appInfos/{id}/ageRatingDeclaration`。

### PATCH /v1/ageRatingDeclarations/{id}

```json
{
  "data": {
    "type": "ageRatingDeclarations",
    "id": "<declarationID>",
    "attributes": {
      "gamblingSimulated": "INFREQUENT_OR_MILD",
      "unrestrictedWebAccess": false,
      "seventeenPlus": false
    }
  }
}
```

属性值：`NONE` / `INFREQUENT_OR_MILD` / `FREQUENT_OR_INTENSE`（部分新属性为 `NONE` / `INFREQUENT` / `FREQUENT`）；布尔类（`gambling`、`unrestrictedWebAccess`、`seventeenPlus`）直接 true/false；`kidsAgeBand` 为 `FIVE_AND_UNDER` / `SIX_TO_EIGHT` / `NINE_TO_ELEVEN`。只发送要改的字段。

---

## 9. Xcode Cloud

| 方法 | 路径 | 用途 | 对应工具 |
|------|------|------|----------|
| GET | `/v1/ciProducts` | 列出 CI 产品 | `app_store_connect_list_ci_products` |
| GET | `/v1/ciProducts/{id}/workflows` | 列出工作流 | `app_store_connect_list_ci_workflows` |
| GET | `/v1/ciWorkflows/{id}` | 读工作流详情 | `app_store_connect_read_ci_workflow` |
| GET | `/v1/ciWorkflows/{id}/buildRuns` | 构建运行记录 | `app_store_connect_list_ci_build_runs` |
| POST | `/v1/ciBuildRuns` | 启动构建 | `app_store_connect_start_ci_build_run` |
| PATCH | `/v1/ciWorkflows/{id}` | 启用/停用工作流 | `app_store_connect_set_ci_workflow_enabled` |

### POST /v1/ciBuildRuns（启动构建）

```json
{
  "data": {
    "type": "ciBuildRuns",
    "attributes": { "sourceBranchOrTag": "main" },
    "relationships": {
      "workflow": { "data": { "type": "ciWorkflows", "id": "<workflowID>" } }
    }
  }
}
```

- `sourceBranchOrTag` 可省略（用工作流默认分支）。

### PATCH /v1/ciWorkflows/{id}（启用/停用）

```json
{
  "data": {
    "type": "ciWorkflows",
    "id": "<workflowID>",
    "attributes": { "isEnabled": true }
  }
}
```

---

## 10. 已废弃 / 不可用端点（勿用）

| 端点 | 状态 |
|------|------|
| `POST /v1/appStoreVersionSubmissions` | 403，仅允许 DELETE（API 1.7 起用 Review Submissions） |
| `GET /v1/appStoreVersions/{id}/relationships/appStoreVersionSubmission` | 404，资源已移除 |
| `GET /v1/appStoreVersions/{id}/ageRatingDeclaration` | API 4.3 移除，改走 `appInfos` |
| `POST /v1/ageRatingDeclarations` | 不存在，只能在网站创建 |
| `POST /v1/apps` | 不存在，App 必须在网站创建 |
