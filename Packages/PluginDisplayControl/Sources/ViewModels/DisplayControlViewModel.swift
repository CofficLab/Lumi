import CoreGraphics
import SwiftUI

@MainActor
final class DisplayControlViewModel: ObservableObject {
    @Published private(set) var displays: [ControlledDisplay] = []
    private let service: DisplayService

    init(service: DisplayService = .shared) { self.service = service }
    func apply(_ service: DisplayService) { displays = service.displays }
    func refresh() { service.refresh() }
    func restoreDefaults() { service.restoreDefaults() }
    func value(for control: DisplayControlKind, displayID: CGDirectDisplayID) -> Double { service.value(for: control, displayID: displayID) }
    func setValue(_ value: Double, for control: DisplayControlKind, displayID: CGDirectDisplayID) { service.setValue(value, for: control, displayID: displayID) }
}
