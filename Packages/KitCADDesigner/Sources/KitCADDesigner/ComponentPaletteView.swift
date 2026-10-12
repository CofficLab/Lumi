import SwiftUI

private typealias L = CADDesignerLocalization

/// 组件库面板：浏览欧标型材/连接件目录，点击添加到场景。
struct ComponentPaletteView: View {
    @ObservedObject var viewModel: CADWorkspaceViewModel
    @State private var searchText = ""

    private var filteredProfiles: [(ProfileSeries, [ProfileSpec])] {
        let all = viewModel.library.profiles
        let grouped = ProfileSeries.allCases.map { series in
            (series, all.filter { $0.series == series })
        }
        if searchText.isEmpty { return grouped }
        let needle = searchText.lowercased()
        return grouped.map { (series, specs) in
            (series, specs.filter { $0.name.lowercased().contains(needle) || $0.id.lowercased().contains(needle) })
        }.filter { !$0.1.isEmpty }
    }

    private var filteredConnectors: [ConnectorSpec] {
        let all = viewModel.library.connectors
        if searchText.isEmpty { return all }
        let needle = searchText.lowercased()
        return all.filter { $0.name.lowercased().contains(needle) || $0.id.lowercased().contains(needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.string("Components"))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            TextField(L.string("Search components"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredProfiles, id: \.0) { series, specs in
                        profileSection(series: series, specs: specs)
                    }

                    if !filteredConnectors.isEmpty {
                        connectorSection
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func profileSection(series: ProfileSeries, specs: [ProfileSpec]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(L.string("Profiles")) · \(series.displayName)")
                .font(.subheadline.weight(.semibold))

            LazyVStack(spacing: 8) {
                ForEach(specs) { spec in
                    profileRow(spec)
                }
            }
        }
    }

    private func profileRow(_ spec: ProfileSpec) -> some View {
        Button {
            viewModel.placeProfile(spec: spec)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cube.fill")
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(spec.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text("\(spec.sizeLabel) · \(String(format: "%.2f", spec.weightPerMeter)) kg/m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14))
            }
            .padding(8)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .help(L.string("Add"))
    }

    private var connectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.string("Connectors"))
                .font(.subheadline.weight(.semibold))

            LazyVStack(spacing: 8) {
                ForEach(filteredConnectors) { spec in
                    connectorRow(spec)
                }
            }
        }
    }

    private func connectorRow(_ spec: ConnectorSpec) -> some View {
        Button {
            viewModel.placeConnector(spec: spec)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: spec.kind.systemImage)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(spec.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text("\(spec.kind.displayName) · \(String(format: "%.0f", spec.unitWeight * 1000)) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14))
            }
            .padding(8)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .help(L.string("Add"))
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
    }
}
