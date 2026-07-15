import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public struct EditorPanelHostView: View {
    let lumiCore: any LumiCoreAccessing

    public init(lumiCore: any LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        EditorPanelView(lumiCore: lumiCore)
    }
}
