import Foundation
import NetworkExtension
import PluginNetto

autoreleasepool {
    NEProvider.startSystemExtensionMode()
    IPCConnection.shared.startListener()
}

dispatchMain()
