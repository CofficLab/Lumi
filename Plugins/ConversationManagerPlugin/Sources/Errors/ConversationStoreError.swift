import Foundation
import KernelLumi
import os
import SuperLogKit
import SwiftData

public enum ConversationStoreError: Error, LocalizedError {
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .initializationFailed(message):
            return message
        }
    }
}
