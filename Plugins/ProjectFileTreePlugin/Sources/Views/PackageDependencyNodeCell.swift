import AppKit
import SwiftUI
import LumiUI

// MARK: - Package Node Row View

/// 软件包依赖行视图（SwiftUI 部分）
struct PackageDependencyNodeRowView: View {
    let item: CollectionItem
    let isSelected: Bool
    let isHovered: Bool
    let palette: FileTreeRowPalette
    let colorScheme: ColorScheme
    let appearanceID: String

    var body: some View {
        Group {
            switch item {
            case .packageHeader(let header):
                headerRow(header: header)
            case .packageDependency(let dep):
                dependencyRow(dep: dep)
            case .file:
                EmptyView()
            }
        }
        .environment(\.colorScheme, colorScheme)
        .id(appearanceID)
    }

    // MARK: Header

    private func headerRow(header: PackageHeaderItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(palette.textTertiary)
                .frame(width: 12)
                .rotationEffect(.degrees(header.isExpanded ? 90 : 0))

            Image(systemName: "shippingbox")
                .font(.system(size: 12))
                .foregroundColor(palette.accentPrimary)
                .frame(width: 16)

            Text(LumiPluginLocalization.string("Package Dependencies", bundle: .module))
                .font(.appCaption)
                .foregroundColor(palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if header.dependencyCount != 0 {
                Text("\(header.dependencyCount)")
                    .font(.appMicro)
                    .foregroundColor(palette.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground())
    }

    // MARK: Dependency

    private func dependencyRow(dep: PackageDependencyNodeItem) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 12) // chevron 占位

            Image(systemName: dep.isLocal ? "folder" : "cube.transparent")
                .font(.system(size: 12))
                .foregroundColor(dep.isLocal ? palette.textSecondary : palette.accentPrimary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(dep.displayName)
                    .font(.appCaption)
                    .foregroundColor(palette.textPrimary)
                    .lineLimit(1)

                Text(dep.subtitle)
                    .font(.appMicro)
                    .foregroundColor(palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, 22) // 缩进 1 级
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground())
    }

    // MARK: Background

    private func rowBackground() -> some View {
        ZStack(alignment: .leading) {
            if isSelected {
                palette.selectionBackground
            } else if isHovered {
                palette.hoverBackground
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - PackageDependencyNodeCell

/// 软件包依赖单元格
final class PackageDependencyNodeCell: NSCollectionViewItem {

    private var hostingView: PackageHostingView?
    private var isHovered = false
    private var cachedItem: CollectionItem?
    private var cachedIsSelected = false
    private var cachedPalette: FileTreeRowPalette?
    private var cachedColorScheme: ColorScheme = .light
    private var cachedAppearanceID = ""

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        hostingView = PackageHostingView(rootView: placeholderRowView())
        hostingView?.translatesAutoresizingMaskIntoConstraints = false

        if let hostingView = hostingView {
            view.addSubview(hostingView)

            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    func configure(
        with item: CollectionItem,
        isSelected: Bool,
        isHovered: Bool,
        palette: FileTreeRowPalette,
        colorScheme: ColorScheme,
        appearance: NSAppearance,
        appearanceID: String
    ) {
        self.isHovered = isHovered
        self.cachedItem = item
        self.cachedIsSelected = isSelected
        self.cachedPalette = palette
        self.cachedColorScheme = colorScheme
        self.cachedAppearanceID = appearanceID
        hostingView?.appearance = appearance

        hostingView?.rootView = PackageDependencyNodeRowView(
            item: item,
            isSelected: isSelected,
            isHovered: isHovered,
            palette: palette,
            colorScheme: colorScheme,
            appearanceID: appearanceID
        )
    }

    func updateHovered(_ hovered: Bool) {
        guard let item = cachedItem, let palette = cachedPalette else { return }
        isHovered = hovered
        hostingView?.rootView = PackageDependencyNodeRowView(
            item: item,
            isSelected: cachedIsSelected,
            isHovered: hovered,
            palette: palette,
            colorScheme: cachedColorScheme,
            appearanceID: cachedAppearanceID
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.rootView = placeholderRowView()
        isHovered = false
        cachedItem = nil
        cachedIsSelected = false
        cachedPalette = nil
        cachedColorScheme = .light
        cachedAppearanceID = ""
    }

    private func placeholderRowView() -> PackageDependencyNodeRowView {
        let header = PackageHeaderItem(
            isExpanded: false,
            dependencyCount: 0,
            projectRootPath: ""
        )
        return PackageDependencyNodeRowView(
            item: .packageHeader(header),
            isSelected: false,
            isHovered: false,
            palette: FileTreeRowPalette(
                theme: LumiFallbackChromeTheme(),
                uiTheme: LumiDefaultTheme(),
                appearance: NSAppearance(named: .aqua)!
            ),
            colorScheme: .light,
            appearanceID: "placeholder"
        )
    }
}

// MARK: - Hosting View

final class PackageHostingView: NSHostingView<PackageDependencyNodeRowView> {
    // 与 NodeRowHostingView 类似，右键事件转发由 controller 处理
}
