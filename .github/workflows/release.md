# macOS App 使用 GitHub Actions 自动发布

## 一、将要实现什么

当你 push 一个 tag（例如 v1.0.0）后：

1.	GitHub Actions 自动运行
2.	使用 Xcode 构建 .app
3.	使用 Developer ID Application 证书签名
4.	打包成 .dmg
5.	提交 Apple Notarization
6.	Staple 公证票据
7.	自动创建 GitHub Release 并上传 DMG

⚠️ 这是 Apple 允许的最大自动化程度

⸻

## 二、需要准备的东西（总览）

| 项目 | 是否必须 | 说明 |
| --- | --- | --- |
| Apple Developer Program | ✅ | 年费 $99 |
| Developer ID Application 证书 | ✅ | 用于非商店分发 |
| 证书私钥（p12） | ✅ | CI 中使用 |
| App Store Connect API Key | ✅ | 用于 Notarization |
| GitHub Actions（macOS runner） | ✅ | 构建环境 |


⸻

## 三、本地一次性准备（最重要）

⚠️ 这一部分 只能在你自己的 Mac 上完成，不能在 CI 中做

1️⃣ 创建 Developer ID Application 证书
	1.	打开 Keychain Access（钥匙串）
	2.	菜单：Certificate Assistant → Request a Certificate from a Certificate Authority
	3.	填写邮箱
	4.	选择：Saved to disk
	5.	生成 .certSigningRequest

前往：

https://developer.apple.com/account/resources/certificates

	•	创建 Developer ID Application 证书
	•	上传 CSR
	•	下载证书并双击安装

验证：

security find-identity -v -p codesigning

看到类似：

Developer ID Application: Your Company (TEAMID)

说明成功。

⸻

2️⃣ 导出 p12（CI 必需）

在 Keychain Access 中：
	•	找到 Developer ID Application
	•	右键 → Export
	•	格式选择 .p12
	•	设置一个密码（记住）

得到：

DeveloperID.p12


⸻

3️⃣ 创建 App Store Connect API Key（用于公证）

前往：

https://appstoreconnect.apple.com/access/api

	•	创建 API Key
	•	权限：Developer 即可
	•	下载 .p8
	•	记下：
	•	Key ID
	•	Issuer ID

⸻

## 四、把敏感信息放进 GitHub Secrets

进入你的 GitHub 仓库：

Settings → Secrets and variables → Actions

1️⃣ 证书相关

base64 DeveloperID.p12 > cert.txt

添加 Secrets：

Name	内容
BUILD_CERTIFICATE_BASE64	cert.txt 内容
BUILD_CERTIFICATE_P12_PASSWORD	p12 密码


⸻

2️⃣ App Store Connect API

base64 AuthKey_XXXX.p8 > api.txt

Name	内容
APP_STORE_CONNECT_KEY_BASE64	api.txt 内容
APP_STORE_CONNECT_KEY_ID	Key ID
APP_STORE_CONNECT_KEY_ISSUER_ID	Issuer ID


⸻

## 五、项目中必须具备的配置

1️⃣ Xcode Signing 设置

在 Xcode 中：
	•	Signing & Capabilities
	•	Team：你的开发者账号
	•	Signing Certificate：Developer ID Application
	•	不需要 Provisioning Profile

⚠️ 不要勾选 Automatically manage signing（CI 更可控）

⸻

2️⃣ 确保可命令行构建

xcodebuild \
  -scheme YourApp \
  -configuration Release \
  -destination "generic/platform=macOS"

必须能成功。

⸻

## 六、GitHub Actions 工作流（核心）

创建：

.github/workflows/release.yml

触发方式（推荐）

on:
  push:
    tags:
      - "v*"


⸻

核心流程说明（概念）

Checkout
↓
导入证书（临时 keychain）
↓
Xcode build
↓
codesign
↓
生成 DMG
↓
notarytool submit
↓
stapler staple
↓
GitHub Release


⸻

## 七、CI 中的签名与公证原理（你需要理解的）

为什么要 keychain？
	•	codesign 只能从 keychain 读取私钥
	•	GitHub Runner 是干净的机器
	•	所以需要：
	•	创建临时 keychain
	•	导入 p12

⸻

为什么 notarize 需要 API key？
	•	Apple 已弃用 Apple ID + 密码
	•	notarytool 只接受 API Key
