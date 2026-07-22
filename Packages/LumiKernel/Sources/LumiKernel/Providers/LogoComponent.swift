import Foundation
import os.log
import SwiftUI

/// LumiCore 的"Logo"功能组件。
@MainActor
public final class LogoComponent: ObservableObject {
    @Published public private(set) var bestItem: LogoItem?

    public init() {}

    public func register(_ items: [LogoItem]) {
        self.bestItem = items.max(by: { $0.order < $1.order })
    }
}
