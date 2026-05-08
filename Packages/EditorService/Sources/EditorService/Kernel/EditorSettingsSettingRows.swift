import SwiftUI

// Shared list-row chrome for editor settings (package-local; avoids AppUI / DesignTokens).
private struct EditorSettingsRowChrome<Content: View>: View {
    let content: Content
    @State private var isHovering = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(rowBackground)
            .overlay(rowBorder)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
    }

    private var rowBackground: some View {
        Group {
            if isHovering {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.06))
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder private var rowBorder: some View {
        if isHovering {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }
}

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
        EditorSettingsRowChrome {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
        }
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
        EditorSettingsRowChrome {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Stepper(value: $value, in: range) {
                    Text("\(value)")
                        .frame(minWidth: 28, alignment: .trailing)
                }
                .frame(width: 112)
            }
        }
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
        EditorSettingsRowChrome {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text("\(option)").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
        }
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
        EditorSettingsRowChrome {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
        }
    }
}
