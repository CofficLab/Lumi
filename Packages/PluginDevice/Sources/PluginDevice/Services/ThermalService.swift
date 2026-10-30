import Foundation

/// CPU / die 温度采集服务。
///
/// 与其他采集服务保持一致:`@MainActor` + `ObservableObject` + 引用计数订阅,
/// 最后一个订阅者离开时自动停止定时器。
@MainActor
public final class ThermalService: ObservableObject {
    public static let shared = ThermalService()

    // MARK: - Published Properties

    /// 全部有效温度读数,按传感器下标升序。
    @Published public private(set) var readings: [ThermalSensorReading] = []

    /// 最高温度读数(℃);无数据时为 `nil`。
    ///
    /// 用 `nil` 而非 `0` 表达「读不到」,以便 UI 区分「没有温度数据」
    /// 与「温度真的是 0℃」。
    @Published public private(set) var peakCelsius: Double?

    // MARK: - Private Properties

    private var timer: Timer?
    private var subscribersCount = 0

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        guard timer == nil else { return }

        sample()

        let newTimer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        guard subscribersCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Sampling

    private func sample() {
        // HID 读取涉及 CF 对象遍历,放到后台避免阻塞主线程。
        Task.detached(priority: .utility) { [weak self] in
            let snapshot = ThermalSensorReader.read()
            let peak = snapshot.map(\.celsius).max()

            await MainActor.run {
                guard let self, self.subscribersCount > 0 else { return }
                self.readings = snapshot
                self.peakCelsius = peak
            }
        }
    }
}
