# App Screenshots API

管理 App Store 应用截图和预览图。

## Resources

- **App Screenshot Sets**: 截图集（按设备和类型分组）
- **App Screenshots**: 单个截图文件

## App Screenshot Sets

### Resource Information

- **Type**: `appScreenshotSets`
- **Base Path**: `/v1/appScreenshotSets`

### Endpoints

#### List Screenshot Sets

获取 App Store 版本的所有截图集。

```
GET /v1/appScreenshotSets
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[appStoreVersionLocalization]` | string[] | No | 按本地化 ID 过滤 |
| `filter[screenshotDisplayType]` | string[] | No | 按显示类型过滤 |
| `fields[appScreenshotSets]` | string[] | No | 指定返回的字段 |
| `include` | string[] | No | 包含相关资源 |

#### Create a Screenshot Set

创建新的截图集。

```
POST /v1/appScreenshotSets
```

#### Request Body

```json
{
  "data": {
    "type": "appScreenshotSets",
    "attributes": {
      "screenshotDisplayType": "APP_IPHONE_65"
    },
    "relationships": {
      "appStoreVersionLocalization": {
        "data": {
          "type": "appStoreVersionLocalizations",
          "id": "loc-123"
        }
      }
    }
  }
}
```

#### Delete a Screenshot Set

删除截图集及其所有截图。

```
DELETE /v1/appScreenshotSets/{id}
```

### Screenshot Display Types

| Type | Description |
|------|-------------|
| `APP_IPHONE_65` | iPhone 6.5" 显示屏 |
| `APP_IPHONE_61` | iPhone 6.1" 显示屏 |
| `APP_IPHONE_58` | iPhone 5.8" 显示屏 |
| `APP_IPHONE_55` | iPhone 5.5" 显示屏 |
| `APP_IPHONE_47` | iPhone 4.7" 显示屏 |
| `APP_IPHONE_40` | iPhone 4.0" 显示屏 |
| `APP_IPHONE_35` | iPhone 3.5" 显示屏 |
| `APP_IPAD_PRO_3GEN_129` | iPad Pro 12.9" (3代) |
| `APP_IPAD_PRO_3GEN_11` | iPad Pro 11" (3代) |
| `APP_IPAD_PRO_129` | iPad Pro 12.9" |
| `APP_IPAD_105` | iPad 10.5" |
| `APP_IPAD_97` | iPad 9.7" |
| `APP_DESKTOP` | macOS 桌面 |
| `APP_WATCH_SERIES_7` | Apple Watch Series 7 |
| `APP_WATCH_SERIES_4` | Apple Watch Series 4 |
| `APP_WATCH_SERIES_3` | Apple Watch Series 3 |
| `APP_APPLE_TV` | Apple TV |

## App Screenshots

### Resource Information

- **Type**: `appScreenshots`
- **Base Path**: `/v1/appScreenshots`

### Endpoints

#### List Screenshots

获取截图集中的所有截图。

```
GET /v1/appScreenshots
```

#### Read Screenshot

获取单个截图信息。

```
GET /v1/appScreenshots/{id}
```

#### Upload a Screenshot

上传新截图。

```
POST /v1/appScreenshots
```

#### Request Body

```json
{
  "data": {
    "type": "appScreenshots",
    "attributes": {
      "fileSize": 1234567,
      "fileName": "screenshot1.png"
    },
    "relationships": {
      "appScreenshotSet": {
        "data": {
          "type": "appScreenshotSets",
          "id": "set-123"
        }
      }
    }
  }
}
```

**注意**: 实际文件上传需要通过预签名 URL 完成。

#### Update Screenshot Order

更新截图顺序。

```
PATCH /v1/appScreenshots/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "appScreenshots",
    "id": "screenshot-123",
    "attributes": {
      "sourceFileChecksum": "abc123",
      "uploadOperations": []
    }
  }
}
```

#### Delete a Screenshot

删除单个截图。

```
DELETE /v1/appScreenshots/{id}
```

### Object Schema

#### App Screenshot Set

```json
{
  "type": "appScreenshotSets",
  "id": "string",
  "attributes": {
    "screenshotDisplayType": "string"
  },
  "relationships": {
    "appScreenshots": "object",
    "appStoreVersionLocalization": "object"
  }
}
```

#### App Screenshot

```json
{
  "type": "appScreenshots",
  "id": "string",
  "attributes": {
    "fileSize": "integer",
    "fileName": "string",
    "sourceFileChecksum": "string",
    "imageAsset": {
      "templateUrl": "string",
      "width": "integer",
      "height": "integer"
    },
    "assetToken": "string",
    "uploadOperations": []
  },
  "relationships": {
    "appScreenshotSet": "object"
  }
}
```

## Screenshot Requirements

### File Specifications

- **格式**: PNG, JPEG, TIFF
- **色彩配置**: sRGB 或 P3
- **文件大小**: 最大 8MB (iOS), 最大 16MB (macOS)
- **分辨率**: 必须符合设备要求

### iOS Screenshot Requirements

| Device | Resolution (Portrait) | Resolution (Landscape) |
|--------|----------------------|----------------------|
| iPhone 6.5" | 1242 x 2688 | 2688 x 1242 |
| iPhone 6.1" | 828 x 1792 | 1792 x 828 |
| iPhone 5.5" | 1242 x 2208 | 2208 x 1242 |
| iPad Pro 12.9" | 2048 x 2732 | 2732 x 2048 |

### Number of Screenshots

- 每个截图集最多 10 张截图
- 至少需要 1 张截图（某些设备类型）
- 建议上传主要设备的截图

## Upload Workflow

1. **创建截图集**
   ```
   POST /v1/appScreenshotSets
   ```

2. **获取上传信息**
   ```
   POST /v1/appScreenshots
   ```
   响应包含预签名 URL 和上传操作

3. **上传文件**
   使用预签名 URL 上传截图文件

4. **验证上传**
   检查截图状态和处理结果

## Related Documentation

- [App Store Version Localizations API](app_store_version_localizations.md)
- [App Store Versions API](app_store_versions.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [App Screenshots - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_screenshots)
- [App Screenshot Sets - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app_screenshot_sets)
