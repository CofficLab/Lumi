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

## 二、需要准备的东西

| 项目 | 说明 |
| --- | --- |
| Apple Developer Program | 年费 $99 |
| Developer ID Application 证书| 用于非商店分发 |
| 证书私钥（p12） | CI 中使用 |
| App Store Connect API Key | 用于 Notarization |

## 三、本地一次性准备（最重要）

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

