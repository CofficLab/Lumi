import Foundation
import NetworkExtension
import NettoPlugin

autoreleasepool {
    NEProvider.startSystemExtensionMode()
    IPCConnection.shared.startListener()
}

dispatchMain()
