import Foundation
import os

enum AppLogger {
    static let core = os.Logger(subsystem: "com.coffic.lumi", category: "core")
    static let layout = os.Logger(subsystem: "com.coffic.lumi", category: "layout")
}