import Foundation
import SwiftUI
public struct OnboardingPageItem: Identifiable, Sendable { public let id: String; public let makeView: @MainActor @Sendable () -> AnyView; public init<Content: View>(id: String, @ViewBuilder content: @escaping @MainActor @Sendable () -> Content) { self.id = id; self.makeView = { AnyView(content()) } } }
@MainActor public protocol OnboardingProviding: AnyObject { var allPages: [OnboardingPageItem] { get }; func register(_ page: OnboardingPageItem); func unregister(id: String) }
@MainActor public final class DefaultOnboardingProviding: OnboardingProviding { public private(set) var allPages: [OnboardingPageItem] = []; public init() {}; public func register(_ page: OnboardingPageItem) { allPages.removeAll { $0.id == page.id }; allPages.append(page) }; public func unregister(id: String) { allPages.removeAll { $0.id == id } } }
