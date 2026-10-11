# App Store Connect 工具使用指南

当用户需要管理 App Store Connect 应用、创建 iOS 或 macOS 版本、填写商店信息、上传截图、关联构建或提交审核时，使用本插件提供的 Agent 工具。

## 重要边界

- 开始前确认 App Store Connect 插件已经配置 Issuer ID、Key ID 和 `.p8` 私钥。
- 所有工具都需要使用 App Store Connect 的真实 ID，不要猜测应用、版本、本地化、截图集、截图或构建 ID。
- 创建版本、关联构建、提交审核、撤回提交和上传截图会修改远端数据。执行这些操作前确认目标和参数。
- 插件不能创建 iOS 工程、Bundle ID、证书或签名，也不能上传 `.ipa`。构建必须先通过 Xcode、Transporter 或已配置的 Xcode Cloud 工作流上传并处理完成。
- App Store Connect 最终审核前置条件可能还包括年龄分级、隐私信息、价格与可用地区、审核联系信息等插件未覆盖的内容。提交失败时，读取 Apple 返回的错误并引导用户到 App Store Connect 补充配置。
- 调试时可以直接用 curl 调用 App Store Connect API（见下文「直接用 curl 调试 App Store Connect API」），不必依赖内置工具。

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

## 直接用 curl 调试 App Store Connect API

默认优先使用本插件的内置工具。以下场景可以直接用 curl 发起最原始的 API 请求来调试或验证：

- 内置工具返回的错误含糊，需要查看 Apple 返回的原始 JSON 错误明细（`errors[].detail`、`errors[].meta.associatedErrors`）。
- 需要验证端点、查询参数或响应结构的行为（例如某些 `fields[...]` 过滤会让 `include` 返回的 `relationships` 被清空这类怪癖）。
- 需要探测插件尚未覆盖的只读端点。

### 获取凭据

凭据保存在 macOS 钥匙串（服务 `com.coffic.lumi.appstoreconnect`），用 `security` 命令读取：

```bash
ISSUER=$(security find-generic-password -s com.coffic.lumi.appstoreconnect -a appStoreConnect.issuerID -w)
KEY_ID=$(security find-generic-password -s com.coffic.lumi.appstoreconnect -a appStoreConnect.keyID -w)
PRIVATE_KEY=$(security find-generic-password -s com.coffic.lumi.appstoreconnect -a appStoreConnect.privateKey -w)
```

若系统弹出钥匙串授权，选择允许；若 CLI 无权读取，请用户直接提供 Key ID、Issuer ID 和 `.p8` 私钥文本。

注：钥匙串里的私钥可能是十六进制编码（不是明文 PEM），上面的 JWT 脚本会自动还原，无需手动处理。

### 生成 JWT（ES256，20 分钟有效）

用 python 生成（已处理钥匙串私钥可能是十六进制编码的情况；签名必须是原始 r||s 拼接，不能直接用 `openssl dgst -sign` 的 DER 输出）：

```bash
TOKEN=$(ISSUER="$ISSUER" KEY_ID="$KEY_ID" PRIVATE_KEY="$PRIVATE_KEY" python3 - <<'PY'
import base64, json, os, subprocess, time

def b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def parse_sig(der):
    assert der[0] == 0x30
    i = 2
    assert der[i] == 0x02
    rl = der[i + 1]; i += 2
    r = int.from_bytes(der[i:i + rl], "big"); i += rl
    assert der[i] == 0x02
    sl = der[i + 1]; i += 2
    s = int.from_bytes(der[i:i + sl], "big")
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")

key = os.environ["PRIVATE_KEY"]
if "-----BEGIN" not in key:
    key = bytes.fromhex(key.strip()).decode()
open("/tmp/asc-key.p8", "w").write(key)
os.chmod("/tmp/asc-key.p8", 0o600)

header = b64url(json.dumps({"alg": "ES256", "kid": os.environ["KEY_ID"]}).encode())
now = int(time.time())
payload = b64url(json.dumps({"iss": os.environ["ISSUER"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", "/tmp/asc-key.p8"],
                     input=(header + "." + payload).encode(), capture_output=True).stdout
print(header + "." + payload + "." + b64url(parse_sig(der)))
PY
)
```

### curl 示例

```bash
# 只读：读取版本详情
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/appStoreVersions/<versionID>"

# 只读：include + 字段过滤（验证响应结构时常用）
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/appStoreVersions/<versionID>?include=app&fields[apps]=name"

# 写操作示例：创建审核提交（先确认 appID 与目标，再执行）
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"data":{"type":"reviewSubmissions","relationships":{"app":{"data":{"type":"apps","id":"<appID>"}}}}}' \
  "https://api.appstoreconnect.apple.com/v1/reviewSubmissions"
```

### 注意事项

- 排查优先使用只读 GET；确需用 curl 执行写操作时，与内置工具同等确认目标和参数。
- token 20 分钟后过期，长时间会话需重新生成；不要把私钥或 token 写入聊天记录、日志或仓库。
- 服务器原始 JSON 错误（`errors[].detail`、`errors[].meta.associatedErrors`）比工具转述的字符串更完整，调试模糊报错时以原始响应为准。
- 用完清理临时私钥：`rm -f /tmp/asc-key.p8`。

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

## 已知经验与排查记录

- **Beta 版 Xcode 构建无法提交**：用 Beta 版 Xcode 构建并上传的构建，提交审核时会被 Apple 拒绝。官网提示"此构建版本使用的是 Beta 版 Xcode，无法提交，请确保使用最新版本的 Xcode"；API 侧返回 `Build Xcode build is not yet supported.`（错误码 `BUILD_XCODE_NOT_ALLOWED_FOR_APP_STORE_SUBMISSION`）。修复：用正式版 Xcode 重新构建并上传，等待处理完成后重新分配构建并提交。
- **`include` 带 `fields[...]` 会清空 relationships**：`GET /v1/appStoreVersions/{id}?include=app&fields[appStoreVersions]=...` 这类组合会让响应里的 `data.relationships` 被清空（included 数组仍在）。排查时优先用 `fields[apps]=name` 而不是 `fields[appStoreVersions]`；遇到关系指针为空时，从 `included` 数组按 `type` 兜底匹配。
- **审核联系信息缺失**：新版本首次提交时，如果 App 审核联系信息（姓名 / 邮箱 / 电话）未填写，API 会返回 409 且明细里列出 `appStoreReviewDetails` 缺失字段。先 `GET /v1/appStoreVersions/{id}/appStoreReviewDetail` 确认，缺则 `PATCH /v1/appStoreReviewDetails/{id}` 补全（电话需带 `+` 国家码格式）。
- **报错含糊时以原始 JSON 为准**：内置工具或顶层错误字符串可能只显示一句话（例如 "This resource cannot be reviewed, please check associated errors to see why."），真实的校验明细在原始响应的 `errors[].detail` / `errors[].meta.associatedErrors` 里，用上面的 curl 方式读取。
