# App Store Connect 工具使用指南

当用户需要管理 App Store Connect 应用、创建 iOS 或 macOS 版本、填写商店信息、上传截图、关联构建或提交审核时，使用本插件提供的 Agent 工具。

## 重要边界

- 开始前确认 App Store Connect 插件已经配置 Issuer ID、Key ID 和 `.p8` 私钥。
- 所有工具都需要使用 App Store Connect 的真实 ID，不要猜测应用、版本、本地化、截图集、截图或构建 ID。
- 创建版本、关联构建、提交审核、撤回提交和上传截图会修改远端数据。执行这些操作前确认目标和参数。
- 插件不能创建 iOS 工程、Bundle ID、证书或签名，也不能上传 `.ipa`。构建必须先通过 Xcode、Transporter 或已配置的 Xcode Cloud 工作流上传并处理完成。
- App Store Connect 最终审核前置条件可能还包括年龄分级、隐私信息、价格与可用地区、审核联系信息等插件未覆盖的内容。提交失败时，读取 Apple 返回的错误并引导用户到 App Store Connect 补充配置。

## 工具分组

### 应用与版本

| 工具 | 用途 |
|------|------|
| `app_store_connect_list_apps` | 列出应用并获取 `appID` |
| `app_store_connect_list_versions` | 列出应用的所有平台版本并获取 `versionID` |
| `app_store_connect_read_version` | 读取单个版本详情 |
| `app_store_connect_create_version` | 创建新的 iOS、macOS、tvOS 或 visionOS 版本 |
| `app_store_connect_release_version` | 发布处于待开发者发布状态的版本 |

创建 iOS 版本时使用 `platform: "IOS"`。建议先列出版本，确认同一平台没有重复版本或正在进行中的版本，再创建版本。

### 本地化与商店元数据

| 工具 | 用途 |
|------|------|
| `app_store_connect_list_localizations` | 列出版本的本地化 |
| `app_store_connect_create_localization` | 添加新的语言本地化 |
| `app_store_connect_read_localization` | 读取完整商店元数据 |
| `app_store_connect_update_localization` | 更新描述、关键词、推广文本、更新说明和 URL |

更新前先读取当前本地化，保留未要求修改的字段。注意 Apple 对字段长度和 URL 格式有要求。

### 截图

| 工具 | 用途 |
|------|------|
| `app_store_connect_list_screenshot_sets` | 列出本地化下的截图集 |
| `app_store_connect_create_screenshot_set` | 为指定设备类型创建截图集 |
| `app_store_connect_list_screenshots` | 列出截图集中的截图 |
| `app_store_connect_upload_screenshot` | 上传本地 PNG/JPEG 截图 |
| `app_store_connect_delete_screenshot` | 删除截图 |

先根据版本平台选择正确的 `displayType`。iOS 常见类型包括 `APP_IPHONE_67`、`APP_IPHONE_65`、`APP_IPHONE_61`、`APP_IPHONE_58` 和 iPad 类型。上传前确认图片符合 Apple 对设备尺寸、数量和内容的要求；插件的本地校验不是完整的 App Store 审核校验。

### 构建与审核

| 工具 | 用途 |
|------|------|
| `app_store_connect_list_builds` | 列出已上传并处理的构建 |
| `app_store_connect_assign_build` | 将构建关联到 App Store 版本，并可声明出口合规 |
| `app_store_connect_submit_version` | 将版本提交 App Review |
| `app_store_connect_withdraw_submission` | 撤回待审核提交 |

标准顺序是：确认构建已经处理完成 → 列出对应平台构建 → 关联构建 → 确认元数据和截图 → 提交审核。提交前必须提供 `versionID`，并确保版本已关联构建。

### Xcode Cloud

| 工具 | 用途 |
|------|------|
| `app_store_connect_list_ci_products` | 列出 Xcode Cloud 产品 |
| `app_store_connect_list_ci_workflows` | 列出工作流 |
| `app_store_connect_read_ci_workflow` | 读取工作流详情 |
| `app_store_connect_list_ci_build_runs` | 查看构建运行记录 |
| `app_store_connect_start_ci_build_run` | 启动已有工作流 |
| `app_store_connect_set_ci_workflow_enabled` | 启用或停用工作流 |

Xcode Cloud 只能启动和查看已有工作流。启动 iOS 工作流后等待构建完成并处理，再回到构建工具完成版本关联。

## 推荐工作流

```text
1. app_store_connect_list_apps
2. app_store_connect_list_versions
3. app_store_connect_create_version (platform = IOS)
4. app_store_connect_list_localizations / app_store_connect_create_localization
5. app_store_connect_read_localization / app_store_connect_update_localization
6. app_store_connect_create_screenshot_set / app_store_connect_upload_screenshot
7. app_store_connect_list_builds
8. app_store_connect_assign_build
9. app_store_connect_submit_version
```

如果构建还不存在，先使用 Xcode、Transporter 或 Xcode Cloud 完成上传；不要在插件中假设构建已经可用。
