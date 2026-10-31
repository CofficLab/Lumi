#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 温度传感器读取回调。
///
/// - Parameters:
///   - context: 调用方传入的上下文指针,原样回传。
///   - index: 传感器在 HID 服务数组中的下标。
///   - celsius: 摄氏温度。
typedef void (*LumiThermalSensorCallback)(void *context, int index, double celsius);

/// 读取当前所有可用温度传感器,结果通过回调逐个上报。
///
/// 底层走 `IOHIDEventSystemClient`(纯用户态、免 sudo、免 entitlement),
/// 这是 Apple Silicon 上唯一可用的温度来源——SMC 私有 API 在 M 系列已被内核拒绝。
///
/// 采用回调而非返回 CF 容器,是为了让 Swift 侧无需接触 CF 的 retain/release 语义;
/// 所有权问题全部收敛在本 target 内部。
///
/// - Parameters:
///   - context: 原样回传给 `callback` 的上下文指针。
///   - callback: 每读到一个有效温度调用一次。
/// - Returns: 成功上报的传感器数量;0 表示不可用(Intel Mac、私有符号失效等)。
FOUNDATION_EXPORT int LumiReadThermalSensors(void *_Nullable context,
                                             LumiThermalSensorCallback callback);

NS_ASSUME_NONNULL_END
