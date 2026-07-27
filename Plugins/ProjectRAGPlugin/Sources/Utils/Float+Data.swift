import Foundation

extension Array where Element == Float {
    /// 将 Float 数组转换为 Data
    func toData() -> Data {
        guard !isEmpty else { return Data() }
        return withUnsafeBufferPointer { ptr in
            Data(bytes: ptr.baseAddress!, count: ptr.count * MemoryLayout<Float>.size)
        }
    }

    /// 从 Data 创建 Float 数组
    init(data: Data) {
        self = data.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }
}
