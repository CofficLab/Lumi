#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import "ThermalSensorBridge.h"

// MARK: - Private HID Declarations
//
// `IOHIDEventSystemClientCreate` / `IOHIDEventSystemClientSetMatching` /
// `IOHIDEventSystemClientCopyServices` / `IOHIDServiceClientCopyEvent` /
// `IOHIDEventGetFloatValue` 只存在于私有头,公开 SDK 未导出声明,故在此显式声明。
//
// 一律使用裸指针 + 手动 retain/release:这些 C API 返回非托管 CF 对象,
// 若交给 Swift 会与其 CF ARC 标注规则冲突,收敛在本 target 内处理最干净。

typedef struct __IOHIDEventSystemClient *LumiHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *LumiHIDServiceClientRef;
typedef struct __IOHIDEvent *LumiHIDEventRef;

extern LumiHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientSetMatching(LumiHIDEventSystemClientRef client,
                                              CFDictionaryRef matching);
extern CFArrayRef IOHIDEventSystemClientCopyServices(LumiHIDEventSystemClientRef client);
extern LumiHIDEventRef IOHIDServiceClientCopyEvent(LumiHIDServiceClientRef service,
                                                    uint32_t type,
                                                    uint32_t options,
                                                    uint64_t timestamp);
extern double IOHIDEventGetFloatValue(LumiHIDEventRef event, uint32_t field);

/// PMU 温度传感器的 usage page / usage。
#define LUMI_HID_PAGE_TEMPERATURE 0xFF00
#define LUMI_HID_USAGE_TEMPERATURE 5

/// HID 事件类型 15 = temperature。
#define LUMI_HID_EVENT_TYPE_TEMPERATURE 15

/// 有效温度区间。未接负载的传感器返回 -1.x,超出物理范围的大值同样不可信。
#define LUMI_THERMAL_MIN_CELSIUS 1.0
#define LUMI_THERMAL_MAX_CELSIUS 150.0

// MARK: - Implementation

int LumiReadThermalSensors(void *context, LumiThermalSensorCallback callback) {
    @autoreleasepool {
        LumiHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (client == NULL) return 0;

        // 将服务集限定到 PMU 温度传感器(usage page 0xFF00, usage 5)。
        int32_t page = LUMI_HID_PAGE_TEMPERATURE;
        int32_t usage = LUMI_HID_USAGE_TEMPERATURE;
        CFNumberRef key = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &page);
        CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usage);
        CFMutableDictionaryRef matching = CFDictionaryCreateMutable(
            kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if (key != NULL && value != NULL && matching != NULL) {
            CFDictionarySetValue(matching, key, value);
            IOHIDEventSystemClientSetMatching(client, matching);
        }
        if (key != NULL) CFRelease(key);
        if (value != NULL) CFRelease(value);
        if (matching != NULL) CFRelease(matching);

        CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
        if (services == NULL) {
            CFRelease(client);
            return 0;
        }

        const CFIndex count = CFArrayGetCount(services);
        int reported = 0;

        for (CFIndex index = 0; index < count; index++) {
            LumiHIDServiceClientRef service =
                (LumiHIDServiceClientRef)CFArrayGetValueAtIndex(services, index);
            if (service == NULL) continue;

            LumiHIDEventRef event =
                IOHIDServiceClientCopyEvent(service, LUMI_HID_EVENT_TYPE_TEMPERATURE, 0, 0);
            if (event == NULL) continue;

            // 字段索引 = 事件类型 << 16(该 API 的字段寻址方式)。
            double celsius = IOHIDEventGetFloatValue(event, LUMI_HID_EVENT_TYPE_TEMPERATURE << 16);

            if (celsius >= LUMI_THERMAL_MIN_CELSIUS && celsius <= LUMI_THERMAL_MAX_CELSIUS) {
                callback(context, (int)index, celsius);
                reported++;
            }

            CFRelease(event);
        }

        CFRelease(services);
        CFRelease(client);
        return reported;
    }
}
