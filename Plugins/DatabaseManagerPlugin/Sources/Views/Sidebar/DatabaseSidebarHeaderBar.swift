import SwiftUI
import LumiKernel
import LumiUI

/// Database Sidebar 顶部标题栏。
///
/// 左侧显示当前内容对应的图标和标题（Tables / Keys / Connections），
/// 右侧按钮区域包含：
/// - `onLoad`（可选）：数据列表的 Reload 按钮；
/// - `onAdd`（可选）：连接列表的「添加连接」按钮；
/// - `onToggleMode`（可选）：数据/连接列表切换按钮（卡片翻转）。
///
/// 样式与 `ConversationListPlugin.ListView` 的 `headerBar` 保持一致：
/// secondary 图标 + caption 标题 + secondary 0.06 背景，
/// `padding(.horizontal, 10)` / `padding(.vertical, 6)`。
struct DatabaseSidebarHeaderBar: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    /// 显示的标题（"Tables" / "Keys" / "Connections"）。
    let title: String

    /// 标题左侧的系统图标。
    let systemImage: String

    /// 点击 Reload 按钮触发的回调。传 nil 时不显示。
    var onLoad: (() -> Void)? = nil

    /// 点击「添加连接」触发的回调。传 nil 时不显示。
    var onAdd: (() -> Void)? = nil

    /// 点击切换数据/连接列表触发的回调。传 nil 时不显示。
    var onToggleMode: (() -> Void)? = nil

    /// 切换按钮在哪种模式下点击。决定按钮的提示文本和图标朝向。
    /// nil 时使用通用「切换」图标。
    var toggleMode: DatabaseSidebarMode? = nil

    // MARK: - Initialization

    init(
        title: String,
        systemImage: String,
        onLoad: (() -> Void)? = nil,
        onAdd: (() -> Void)? = nil,
        onToggleMode: (() -> Void)? = nil,
        toggleMode: DatabaseSidebarMode? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.onLoad = onLoad
        self.onAdd = onAdd
        self.onToggleMode = onToggleMode
        self.toggleMode = toggleMode
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if let onLoad {
                Button(action: onLoad) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Reload", bundle: .module))
            }

            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Add Connection", bundle: .module))
            }

            if let onToggleMode {
                Button(action: onToggleMode) {
                    Image(systemName: toggleIconName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(toggleHelpText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06))
    }

    private var toggleIconName: String {
        // 同一图标随模式自旋 90°，暗示「卡片翻转」
        "rectangle.portrait.on.rectangle.portrait"
    }

    private var toggleHelpText: String {
        switch toggleMode {
        case .connections:
            return LumiPluginLocalization.string("Show Tables", bundle: .module)
        case .browser:
            return LumiPluginLocalization.string("Show Connections", bundle: .module)
        case .none:
            return LumiPluginLocalization.string("Toggle", bundle: .module)
        }
    }
}

/// 侧边栏内容模式：数据浏览（Tables/Keys）或连接列表。
///
/// 由 ``DatabaseViewModel.sidebarMode`` 持有，两种模式共用同一份
/// 连接配置、但展示不同的子视图，通过 ``SidebarView`` 的 3D 翻转动画切换。
public enum DatabaseSidebarMode: String, Hashable {
    case browser
    case connections
}

#if DEBUG
#Preview("Tables") {
    DatabaseSidebarHeaderBar(title: LumiPluginLocalization.string("Tables", bundle: .module), systemImage: "tablecells", onLoad: {}, onToggleMode: {}, toggleMode: .browser)
        .frame(width: 260)
}

#Preview("Connections") {
    DatabaseSidebarHeaderBar(title: LumiPluginLocalization.string("Connections", bundle: .module), systemImage: "cylinder.split.1x2", onAdd: {}, onToggleMode: {}, toggleMode: .connections)
        .frame(width: 260)
}
#endif
