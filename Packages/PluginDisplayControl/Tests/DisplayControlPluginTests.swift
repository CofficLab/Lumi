import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import Testing
@testable import DisplayControlPlugin

@MainActor
@Test("Plugin info has correct identifier")
func pluginInfoIdentifier() {
    #expect(DisplayControlSuperPlugin().id == "com.coffic.lumi.plugin.display-control")
}

@MainActor
@Test("Plugin info has correct display name")
func pluginInfoDisplayName() {
    #expect(DisplayControlSuperPlugin().metadata.name == LumiPluginLocalization.string("Display Control", bundle: LumiPluginLocalization.resourceBundle))
}

@MainActor
@Test("Plugin category is system")
func pluginCategory() {
    #expect(DisplayControlSuperPlugin().metadata.category == .system)
}

@MainActor
@Test("Plugin policy is optIn")
func pluginPolicy() {
    #expect(DisplayControlSuperPlugin().metadata.policy == .disabledByDefault)
}

@Test("Plugin iconName is display")
func pluginIconName() {
}

@MainActor
@Test("激活显示器控制时隐藏 ChatSection，离开后恢复")
func activationHidesChatSection() throws {
    let kernel = KernelCoreContainer()
    let activity = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()

    try kernel.registerProvider((any ActivityBarProviding).self, activity)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())

    let plugin = DisplayControlSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activity.activeItemID == "com.coffic.lumi.plugin.display-control.entry")
    #expect(!chat.isVisible)

    activity.activateItem(id: nil)

    #expect(chat.isVisible)
}

@Test("DisplayControlKind has correct cases")
func displayControlKinds() {
    let brightness = DisplayControlKind.brightness
    let contrast = DisplayControlKind.contrast
    let volume = DisplayControlKind.volume

    #expect(brightness.icon == "sun.max")
    #expect(contrast.icon == "circle.lefthalf.filled")
    #expect(volume.icon == "speaker.wave.2")
}

@Test("DisplayControlKind default values are correct")
func displayControlKindDefaultValues() {
    #expect(DisplayControlKind.brightness.defaultValue == 50)
    #expect(DisplayControlKind.volume.defaultValue == 40)
    #expect(DisplayControlKind.contrast.defaultValue == 75)
}

@Test("ControlledDisplay initializes correctly")
func controlledDisplayInit() {
    let display = ControlledDisplay(
        id: 1,
        storageID: "test-display",
        name: "Test Display",
        isBuiltIn: false,
        supportsBrightness: true,
        supportsVolume: true,
        supportsContrast: false,
        brightness: 75,
        volume: 30,
        contrast: 50
    )

    #expect(display.id == 1)
    #expect(display.name == "Test Display")
    #expect(display.isBuiltIn == false)
    #expect(display.supports(.brightness) == true)
    #expect(display.supports(.volume) == true)
    #expect(display.supports(.contrast) == false)
    #expect(display.brightness == 75)
    #expect(display.volume == 30)
    #expect(display.contrast == 50)
}
