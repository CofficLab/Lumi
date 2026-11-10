import Foundation

/// 历史采样点的统一契约。
///
/// 视图模型需要按时间范围裁剪历史数据,不同指标(CPU / 内存 / GPU / 温度)
/// 的采样点结构各不相同,但都携带采样时间戳,故用该协议收窄依赖。
public protocol DeviceHistorySample {
    /// 采样时刻(Unix 时间戳,秒)。
    var timestamp: TimeInterval { get }
}
