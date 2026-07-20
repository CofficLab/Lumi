import Foundation
import LumiCoreLLMProvider
import LumiCoreMessage
import SwiftUI

/// Aggregates provider-specific settings views from enabled plugins.
@MainActor
public protocol LumiLLMProviderSettingsContributing: AnyObject {
    func llmProviderSettingsViews(lumiCore: any LumiCoreProviding) -> [LumiLLMProviderSettingsViewItem]
}
