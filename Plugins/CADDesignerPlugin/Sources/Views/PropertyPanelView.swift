import SwiftUI

private typealias L = CADDesignerLocalization

/// 属性编辑面板：选中组件后编辑长度/位置/旋转。
struct PropertyPanelView: View {
    @ObservedObject var viewModel: CADWorkspaceViewModel

    @State private var length: Double = 500
    @State private var posX: Double = 0
    @State private var posY: Double = 0
    @State private var posZ: Double = 0
    @State private var rotY: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.string("Inspector"))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                if let component = viewModel.selectedComponent {
                    componentEditor(component)
                        .padding(12)
                } else {
                    Text(L.string("Select a component to edit it."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: viewModel.selectedComponent?.id) { _, _ in
            syncFromSelection()
        }
        .onAppear { syncFromSelection() }
    }

    @ViewBuilder
    private func componentEditor(_ component: CADComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 组件信息头
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedComponent?.displayName(library: viewModel.library) ?? component.id)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(component.kind == .profile ? L.string("Profiles") : L.string("Connectors"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 长度（仅型材）
            if case .profile(let instance) = component {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.string("Length"))
                        .font(.caption.weight(.semibold))
                    HStack {
                        Slider(value: $length, in: 50...6000, step: 10) { editing in
                            if !editing { applyLength() }
                        }
                        TextField("", value: $length, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                            .onSubmit(applyLength)
                    }
                    Text("\(Int(length)) mm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("profile: \(instance.profileId)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Divider()

            // 位置
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.caption.weight(.semibold))
                positionStepper(label: L.string("Position X"), value: $posX, apply: applyPosition)
                positionStepper(label: L.string("Position Y"), value: $posY, apply: applyPosition)
                positionStepper(label: L.string("Position Z"), value: $posZ, apply: applyPosition)
            }

            Divider()

            // 旋转
            VStack(alignment: .leading, spacing: 8) {
                Text("Rotation")
                    .font(.caption.weight(.semibold))
                HStack {
                    Slider(value: $rotY, in: 0...360, step: 5) { editing in
                        if !editing { applyPosition() }
                    }
                    TextField("", value: $rotY, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .onSubmit(applyPosition)
                }
                Text("\(L.string("Rotation Y")) \(Int(rotY))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 删除按钮
            Button(role: .destructive) {
                viewModel.deleteSelectedComponent()
            } label: {
                Label(L.string("Delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // 测量结果
            if let measurement = viewModel.measurement {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.string("Measure"))
                        .font(.caption.weight(.semibold))
                    Text(String(format: "%.1f mm", measurement.distance))
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private func positionStepper(label: String, value: Binding<Double>, apply: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .onSubmit(apply)
            Stepper("") {
                value.wrappedValue += 10; apply()
            } onDecrement: {
                value.wrappedValue -= 10; apply()
            }
            .labelsHidden()
        }
    }

    // MARK: - Actions

    private func applyLength() {
        viewModel.updateSelectedProfileLength(length)
    }

    private func applyPosition() {
        let transform = Transform3D(
            positionX: posX, positionY: posY, positionZ: posZ,
            rotationY: rotY
        )
        viewModel.updateSelectedComponentTransform(transform)
    }

    private func syncFromSelection() {
        guard let component = viewModel.selectedComponent else { return }
        posX = component.transform.positionX
        posY = component.transform.positionY
        posZ = component.transform.positionZ
        rotY = component.transform.rotationY
        if case .profile(let instance) = component {
            length = instance.length
        }
    }
}
