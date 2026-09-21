# macOS App 使用 GitHub Actions 自动发布

## 一、将要实现什么

当你 push 到 `pre` 或 `main` 后：

1.	GitHub Actions 自动运行
2.	根据 conventional commit 自动计算版本
3.	`prepare` 固定触发提交并生成唯一的发布 metadata
4.	两个隔离的 build job 并行构建、校验 `arm64` 与 `x86_64` 归档
5.	`publish` 验证两份归档的来源、摘要、权限、资源和架构
6.	集中使用 Developer ID Application 证书签名并生成唯一命名的 DMG
7.	提交 Apple Notarization，状态为 Accepted 后 staple 并执行 Gatekeeper 验证
8.	在任何公开写入前保存可恢复的 `final-assets`，再上传并逐字节验证两个 DMG
9.	创建并核验 GitHub Release 草稿，最后依次更新架构 feed、默认 feed 并开放 Release

### 更新通道

直营版用户可以在「设置 → 通用 → 更新 → 更新通道」中选择：

- `稳定版`：读取 `https://s.kuaiyizhi.cn/lumi/appcast-*.xml`，对应 `main`。
- `预览版`：读取 `https://s.kuaiyizhi.cn/lumi/pre/appcast-*.xml`，对应 `pre`，可能包含未修复的问题。

两个通道分别存放 DMG 和 appcast。稳定版客户端优先读取 R2，R2 不可访问时回退到 GitHub Release 的架构 appcast。预览版使用 `pre` 前缀的 R2 路径；预览版的备用地址由客户端通道配置决定。

Sparkle 的构建号使用 UTC 日期格式 `YYYYMMDDHHmmss`，例如 `20260101120000`。发布时先与仓库历史、线上 appcast 的最大构建号比较；如果发生时钟回退或同秒发布，则使用已知最大值加一。stable 和 preview 共用全局发布锁。Lumi 的版本配置只在各 build job 的两份 Lumi xcconfig 中临时注入。stable appcast 不提交；preview 的三份 appcast 会在 CDN 文件确认可用后，以普通、非强制提交同步到最新 `pre`，作为客户端 fallback。

### 发布产物命名

新发布不再复用 `Lumi_版本_架构.dmg`。所有地方都从同一份 metadata 读取名称：

```text
Lumi_<marketing-version>_<build-number>_<arch>.dmg
Lumi_<marketing-version>_<build-number>_<arch>_dSYMs.zip
```

例如 `Lumi_6.1.0_20260921190000_arm64.dmg`。旧版 URL 保持可读；同名新 DMG 若线上字节不同，发布会拒绝覆盖。

### 权限与密钥边界

- `prepare` 与 build matrix 只有仓库只读权限，不接触签名、公证、Sparkle 或 R2 密钥。
- 两个 build job 必须 checkout metadata 中固定的 SHA，使用受版本控制的两套 lock 严格解析。
- 只有 `publish` 获得仓库写权限；各 secret 只注入实际使用它的步骤。
- 缓存只保存锁定依赖源码，不保存最终 App、签名文件、钥匙串或发布 metadata。

### 无发布副作用的构建验证

`.github/workflows/release-build-validation.yml` 可手工运行，也会在 `release-validation/**` 分支运行。它使用与生产相同的 metadata、依赖解析、archive、归档校验和打包脚本，但没有发布凭据，也没有 publish job。用它完成冷缓存、热缓存和单一源码变更的受控对照后，再让正式流程进入 preview 灰度。

## 发布失败与恢复

`final-assets-<run-id>-<build-number>` 会在第一次公开写入前保存 30 天，包含两架构已签名且 stapled 的 DMG、dSYM、appcast、changelog、metadata、每个文件的 SHA256 和 Apple notarization submission ID。上传这份恢复包失败时，不会上传 DMG 或 feed。

重跑 publish 时先寻找同一 run/build 的恢复包：

1. 存在且 metadata、摘要、公证状态全部一致：跳过重新签名和公证，复用原字节并核对线上状态。
2. 不存在：从同一 run/build/arch 的两份归档重新进入签名阶段，禁止使用“最近成功”的其他产物。
3. 同名 DMG 已存在：字节一致则幂等复用，不一致立即停止；每个 build 另有不可变的 `release-state-<build>.json` 绑定 source SHA、通道和所有摘要。
4. 线上 appcast 已出现更高 build：旧任务立即停止；若 build 相等，只有线上 recovery state 与本地 manifest 完全一致才允许继续。
5. GitHub tag 或既有 asset 与固定 source SHA/本地摘要不同：立即停止。
6. 公证等待超时时查询原 submission ID；只有明确 Accepted 才能 staple 和继续。

公开顺序固定为：本地验收 → 保存恢复包 → 两个 DMG → 下载校验公开字节 → GitHub Release 草稿及完整 assets → 两个架构 feed → legacy/default feed → preview fallback 提交 → 开放 GitHub Release。feed 逐文件更新不是跨服务原子事务，但每份可见 feed 都只会指向已经验证可下载的 DMG。

若 artifacts 已过期或 provenance 不一致，应创建新的正常 build，而不是跨 run 拼接或覆盖旧文件。回退并行流程时，回到保留双 lock、正确 ACP 架构和严格归档门禁的串行版本，不能回到可能嵌入宿主架构 helper 的旧路径。

## 二、需要准备的东西

| 项目 | 说明 |
| --- | --- |
| Apple Developer Program | 年费 $99 |
| Developer ID Application 证书| 用于非商店分发 |
| 证书私钥（p12） | CI 中使用 |
| App Store Connect API Key | 用于 Notarization |
| SPARKLE_PRIVATE_KEY | Sparkle使用，保存在 GitHub Actions 中 |
| UTC 日期构建号 | 格式为 `YYYYMMDDHHmmss`，由 workflow 自动生成并校验单调递增 |

为了实现自动检查更新，还需要确保`target - info`中有以下内容：

| Key | Value |
| --- | --- |
| SUPublicEDKey | Sparkle 自动更新系统的公钥，配合私钥使用，私钥保存在 GitHub Actions |
| SUFeedURL | 由 `AppUpdatePlugin` 按架构使用 `https://s.kuaiyizhi.cn/lumi/appcast-*.xml` |
| SUEnableInstallerLauncherService | true |

`SPARKLE_PRIVATE_KEY` 和 `SUPublicEDKey` 最好每个APP都有一对。如果同一个组织下的多个APP共用一对，技术上可行，实践上不推荐。

## 三、本地一次性准备

⚠️ 这一部分只能在自己的 Mac 上完成

### 1、创建 Developer ID Application 证书

1.	打开 Keychain Access（钥匙串）
2.	菜单：Certificate Assistant → Request a Certificate from a Certificate Authority
3.	填写邮箱
4.	选择：Saved to disk
5.	生成 .certSigningRequest

前往：

https://developer.apple.com/account/resources/certificates

- 创建 Developer ID Application 证书
- 上传 CSR
- 下载证书并双击安装

验证：

```bash
security find-identity -v -p codesigning
```

看到类似：

```bash
Developer ID Application: Your Company (TEAMID)
```

说明成功。

### 2、导出 p12（CI 必需）

在 Keychain Access 中：

- 找到 Developer ID Application
- 右键 → Export
- 格式选择 .p12
- 设置一个密码（记住）

得到：

DeveloperID.p12

### 3、创建 App Store Connect API Key（用于公证）

前往：

https://appstoreconnect.apple.com/access/api

- 创建 API Key
- 权限：Developer 即可
- 下载 .p8
- 记下：
	- Key ID
	- Issuer ID

## 四、把敏感信息放进 GitHub Secrets

进入你的 GitHub 仓库：

Settings → Secrets and variables → Actions

### 1、证书相关

base64 DeveloperID.p12 > cert.txt

添加 Secrets：

| Name | 内容 |
|------|------|
| BUILD_CERTIFICATE_BASE64 | cert.txt 内容 |
| BUILD_CERTIFICATE_P12_PASSWORD | p12 密码 |

### 2、App Store Connect API

base64 AuthKey_XXXX.p8 > api.txt

| Name | 内容 |
|------|------|
| APP_STORE_CONNECT_KEY_BASE64 | api.txt 内容 |
| APP_STORE_CONNECT_KEY_ID | Key ID |
| APP_STORE_CONNECT_KEY_ISSUER_ID | Issuer ID |

## 五、独立 app 的发版（Tag → Xcode Cloud）

Lumi 走上面的 Developer ID + Notarization 流程。其余独立 app（AppIconDesigner、CADDesigner、DatabaseManager）走 **git tag → Xcode Cloud** 流程：GitHub Actions 按 conventional commit scope 自动打 tag，Xcode Cloud 监听对应 tag 触发构建发版。BookletMaker 已移除独立 app，只保留 Lumi 内插件，不再拥有独立发布 tag。

### Tag 与 scope 约定

| app | tag 前缀 | conventional commit scope | 版本注入脚本 | xcconfig |
|-----|---------|--------------------------|-------------|----------|
| AppIconDesigner | `appicondesigner-v*` | `appicondesigner` \| `appicondesignerapp` | `set-appicondesigner-version.sh` | `AppIconDesignerApp/AppIconDesigner.xcconfig` |
| CADDesigner | `caddesigner-v*` | `caddesigner` \| `caddesignerapp` | `set-caddesigner-version.sh` | `CADDesignerApp/CADDesigner.xcconfig` |
| DatabaseManager | `databasemanager-v*` | `databasemanager` \| `databasemanagerapp` | `set-databasemanager-version.sh` | `DatabaseManagerApp/DatabaseManager.xcconfig` |

### 流程

1. commit 推到 `main` → 对应的 `*-tag.yml` workflow 按 scope 计算下一个版本并打 tag。
2. Xcode Cloud（在 App Store Connect 后台为每个 app 各配一个 workflow）监听对应 tag 前缀触发构建。
3. `ci_post_clone.sh` 从脚本自身位置定位仓库根目录，再按 `CI_TAG` 前缀分发到对应 `set-*-version.sh`，把版本号写入该 app 的 xcconfig（版本号不进 git 历史）。发布 tag 下若脚本缺失、版本非法或 `CI_BUILD_NUMBER` 非正整数，构建会立即失败，避免上传错误版本。
4. 修改版本注入逻辑后，运行 `.github/scripts/test-ci-version-injection.sh` 回归测试；该脚本会模拟 Xcode Cloud 从 `ci_scripts` 目录启动的行为。
5. Xcode Cloud archive + 上传 TestFlight。

### 给某个 app 发版

提交时带上对应 scope 即可，例如：

```
feat(appicondesigner): 支持导出 1024 图标
fix(caddesigner): 修复导出崩溃
feat(databasemanager): 新增 Redis 连接
```

下一次推 `main` 时对应 workflow 会自动打 tag（`feat` → minor 递增；`fix`/`chore` → patch；`!` → major）。首次从 `*-v1.0.0` 起步。

### 在 App Store Connect 配置 Xcode Cloud（每个 app 一次性）

为每个独立 app 在 ASC 后台新建一个 Xcode Cloud workflow：
- **触发条件**：New tag，匹配该 app 的 tag 前缀（如 `appicondesigner-v*`）。
- **Scheme**：对应 app 的 scheme。
- **脚本**：仓库根 `ci_scripts/` 自动生效（所有 app 共用，通过 `SCHEME_NAME` 环境变量区分）。
