import Foundation

enum SpeedFormatter {
    static func formatForStatusBar(_ bytesPerSecond: Double) -> String {
        let gb = bytesPerSecond / (1024 * 1024 * 1024)
        let mb = bytesPerSecond / (1024 * 1024)
        let kb = bytesPerSecond / 1024

        if gb >= 1 {
            return String(format: "%.1fGB/s", gb)
        } else if mb >= 1 {
            return String(format: "%.1fMB/s", mb)
        } else if kb >= 1 {
            return String(format: "%.0fKB/s", kb)
        } else {
            return String(format: "%.0fB/s", bytesPerSecond)
        }
    }
}
