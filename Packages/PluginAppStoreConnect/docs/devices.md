# Devices API

管理注册的测试设备，用于开发和调试。

## Resource Information

- **Type**: `devices`
- **Base Path**: `/v1/devices`

## Endpoints

### List Devices

获取已注册设备列表。

```
GET /v1/devices
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter[udid]` | string[] | No | 按 UDID 过滤 |
| `filter[name]` | string[] | No | 按设备名称过滤 |
| `filter[platform]` | string[] | No | 按平台过滤 |
| `filter[status]` | string[] | No | 按状态过滤：`ENABLED`, `DISABLED` |
| `sort` | string | No | 排序字段：`id`, `-id`, `name`, `-name`, `platform`, `-platform`, `status`, `-status`, `udid`, `-udid` |
| `fields[devices]` | string[] | No | 指定返回的字段 |
| `limit` | integer | No | 每页数量 (1-200) |

#### Response

```json
{
  "data": [
    {
      "type": "devices",
      "id": "device-123",
      "attributes": {
        "name": "John's iPhone",
        "platform": "IOS",
        "udid": "00008110-001234567890ABCD",
        "status": "ENABLED",
        "model": "iPhone 15 Pro",
        "deviceClass": "IPHONE",
        "addedDate": "2024-01-15T10:30:00.000+00:00"
      },
      "links": {
        "self": "/v1/devices/device-123"
      }
    }
  ]
}
```

### Read Device

获取特定设备的信息。

```
GET /v1/devices/{id}
```

### Register a Device

注册新设备。

```
POST /v1/devices
```

#### Request Body

```json
{
  "data": {
    "type": "devices",
    "attributes": {
      "name": "Test Device",
      "platform": "IOS",
      "udid": "00008110-001234567890ABCD"
    }
  }
}
```

#### Response

```json
{
  "data": {
    "type": "devices",
    "id": "device-456",
    "attributes": {
      "name": "Test Device",
      "platform": "IOS",
      "udid": "00008110-001234567890ABCD",
      "status": "ENABLED",
      "addedDate": "2024-01-15T10:30:00.000+00:00"
    }
  }
}
```

### Update a Device

更新设备信息（名称、状态）。

```
PATCH /v1/devices/{id}
```

#### Request Body

```json
{
  "data": {
    "type": "devices",
    "id": "device-123",
    "attributes": {
      "name": "Updated Device Name",
      "status": "DISABLED"
    }
  }
}
```

## Object Schema

```json
{
  "type": "devices",
  "id": "string",
  "attributes": {
    "name": "string",
    "platform": "string",
    "udid": "string",
    "status": "string",
    "model": "string",
    "deviceClass": "string",
    "addedDate": "string"
  }
}
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | 设备名称 |
| `platform` | string | 平台：`IOS`, `MAC_OS` |
| `udid` | string | 设备唯一标识符 |
| `status` | string | 状态：`ENABLED`, `DISABLED` |
| `model` | string | 设备型号 |
| `deviceClass` | string | 设备类别 |
| `addedDate` | string | 注册日期 |

## Device Classes

| Class | Description |
|-------|-------------|
| `IPHONE` | iPhone |
| `IPAD` | iPad |
| `APPLE_WATCH` | Apple Watch |
| `APPLE_TV` | Apple TV |
| `MAC` | Mac |
| `IPOD` | iPod |

## Device Limits

| Platform | Maximum |
|----------|---------|
| iOS | 100 devices per year |
| macOS | 100 devices per year |
| tvOS | 100 devices per year |
| watchOS | 100 devices per year |

**注意**: 设备数量限制是按年计算的，每年 1 月 1 日重置。

## Get UDID

### macOS
```bash
system_profiler SPUSBDataType | grep "Serial Number"
```

### iOS
1. 连接设备到 Mac
2. 打开 Finder 或 Xcode
3. 在设备信息中查看序列号/UDID

### 通过命令行
```bash
# 列出已连接的 iOS 设备
idevice_id -l
```

## Related Documentation

- [Certificates API](certificates.md)
- [Profiles API](profiles.md)
- [Bundle IDs API](bundle_ids.md)
- [App Store Connect API Reference](api-reference.md)

## Official Documentation

- [Devices - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/devices)
