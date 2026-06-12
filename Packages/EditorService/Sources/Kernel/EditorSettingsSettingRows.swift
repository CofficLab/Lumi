import LumiUI
import SwiftUI

public struct EditorToggleSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    public init(title: String, subtitle: String, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        AppSettingsToggleRow(title, description: subtitle, isOn: $isOn)
    }
}

public struct EditorStepperSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    public init(title: String, subtitle: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.title = title
        self.subtitle = subtitle
        self._value = value
        self.range = range
    }

    public var body: some View {
        AppSettingsStepperRow(title, description: subtitle, value: $value, in: range)
    }
}

public struct EditorSegmentedSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var selection: Int
    let options: [Int]

    public init(title: String, subtitle: String, selection: Binding<Int>, options: [Int]) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        AppSettingsSegmentedPickerRow(title, description: subtitle, selection: $selection, options: options)
    }
}

public struct EditorReadOnlySettingRow: View {
    let title: String
    let subtitle: String
    let badge: String

    public init(title: String, subtitle: String, badge: String) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
    }

    public var body: some View {
        AppSettingsReadOnlyRow(title, description: subtitle, badge: badge)
    }
}
