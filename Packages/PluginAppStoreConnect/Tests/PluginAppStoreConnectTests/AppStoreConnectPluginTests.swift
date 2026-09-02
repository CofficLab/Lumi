import Testing
@testable import PluginAppStoreConnect

@Test("plugin metadata follows the current integration conventions")
@MainActor
func pluginMetadata() {
    let plugin = AppStoreConnectPlugin()

    #expect(plugin.id == "com.coffic.lumi.plugin.app-store-connect")
    #expect(plugin.metadata.id == plugin.id)
    #expect(plugin.metadata.category == .integration)
    #expect(plugin.metadata.stage == .preview)
    #expect(plugin.metadata.policy == .disabledByDefault)
    #expect(AppStoreConnectPlugin.railTabID == "app-store-connect.sidebar")
}

@Test("all restored agent tools use unique current names")
@MainActor
func toolNamesUseCurrentConvention() {
    let names = AppStoreConnectPlugin.agentTools.map(\.name)

    #expect(names.count == 24)
    #expect(Set(names).count == names.count)
    #expect(names.allSatisfy { $0.hasPrefix("app_store_connect_") })
    #expect(names.allSatisfy { !$0.contains("-") && !$0.contains(".") })
}

@Test("schemas expose object roots")
@MainActor
func toolSchemasAreObjects() {
    let schemas = AppStoreConnectPlugin.agentTools.map { $0.inputSchema(for: .english) }
    #expect(schemas.count == 24)
    #expect(schemas.allSatisfy { ($0["type"] as? String) == "object" })
}

@Test("credentials require all App Store Connect signing fields")
func credentialsCompleteness() {
    #expect(!AppStoreConnectCredentials(issuerID: "", keyID: "key", privateKey: "pem").isComplete)
    #expect(!AppStoreConnectCredentials(issuerID: "issuer", keyID: "", privateKey: "pem").isComplete)
    #expect(!AppStoreConnectCredentials(issuerID: "issuer", keyID: "key", privateKey: "").isComplete)
    #expect(AppStoreConnectCredentials(issuerID: "issuer", keyID: "key", privateKey: "pem").isComplete)
}
