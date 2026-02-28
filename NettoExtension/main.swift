import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
    IPCConnection.shared.startListener()
}

dispatchMain()
