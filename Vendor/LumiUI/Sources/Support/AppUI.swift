import SwiftUI

/// Shorthand access to the public design token groups used by LumiUI views.
///
/// Most apps can use `DesignTokens` directly. This namespace is useful when a
/// view reads several token groups and keeps existing LumiUI terminology
/// available to package consumers.
public enum AppUI {
    typealias Color = DesignTokens.Color
    public typealias Typography = DesignTokens.Typography
    public typealias Spacing = DesignTokens.Spacing
    public typealias Radius = DesignTokens.Radius
    public typealias Material = DesignTokens.Material
    public typealias Duration = DesignTokens.Duration
    typealias Motion = DesignTokens.Motion
    public typealias Shadow = DesignTokens.Shadow
}
