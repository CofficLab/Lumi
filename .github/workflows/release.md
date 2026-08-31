# macOS App 使用 GitHub Actions 自动发布

## 一、将要实现什么

当你 push 到 `pre` 或 `main` 后：

1.	GitHub Actions 自动运行
2.	根据 conventional commit 自动计算版本
3.	使用 Xcode 构建 .app
4.	使用 Developer ID Application 证书签名
5.	打包成 .dmg
6.	提交 Apple Notarization
7.	Staple 公证票据并执行 Gatekeeper 验证
8.	自动创建 GitHub Release 并上传 DMG
9.	`main` 发布会生成 stable release 和 appcast；`pre` 发布会生成 prerelease

## 二、需要准备的东西

| 项目 | 说明 |
| --- | --- |
| Apple Developer Program | 年费 $99 |
| Developer ID Application 证书| 用于非商店分发 |
| 证书私钥（p12） | CI 中使用 |
| App Store Connect API Key | 用于 Notarization |
| SPARKLE_PRIVATE_KEY | Sparkle使用，保存在 GitHub Actions 中 |

为了实现自动检查更新，还需要确保`target - info`中有以下内容：

| Key | Value |
| --- | --- |
| SUPublicEDKey | Sparkle 自动更新系统的公钥，配合私钥使用，私钥保存在 GitHub Actions |
| SUFeedURL | https://raw.githubusercontent.com/CofficLab/Lumi/main/appcast.xml |
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

Lumi 走上面的 Developer ID + Notarization 流程。其余独立 app（BookletMaker、AppIconDesigner、CADDesigner、DatabaseManager）走 **git tag → Xcode Cloud** 流程：GitHub Actions 按 conventional commit scope 自动打 tag，Xcode Cloud 监听对应 tag 触发构建发版。

### Tag 与 scope 约定

| app | tag 前缀 | conventional commit scope | 版本注入脚本 | xcconfig |
|-----|---------|--------------------------|-------------|----------|
| BookletMaker | `booklet-v*` | `booklet` \| `bookletmaker` \| `bookletmakerapp` | `set-booklet-version.sh` | `BookletMakerApp/BookletMaker.xcconfig` |
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
