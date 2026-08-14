import KernelLumi
import SwiftUI

// MARK: - Toast Model

/// Web 请求 toast 的状态机:订阅 `.lumiWebRequestReceived`,仅对"写操作且成功"
/// 的请求显示一条瞬时提示,并在 3 秒后自动消失。
///
/// 节流策略:新请求到达时取消上一个消失计时器并重启——连续高频调用不会堆叠
/// 成一串 toast,只会持续刷新当前这一条。
@MainActor
final class WebRequestToastModel: ObservableObject {
    /// 当前显示的 toast;`nil` 表示不显示。
    @Published private(set) var currentToast: Toast?

    private var dismissTask: Task<Void, Never>?
    private static let displayDuration: Duration = .seconds(3)

    struct Toast: Equatable {
        /// 标题:优先用路由 description,缺失时回退到路径。
        let title: String
        /// 副标题:方法 · 插件 · 状态码。
        let detail: String
    }

    /// 由视图的 `.onLumiWebRequestReceived` 调用。
    func handle(_ activity: WebRequestActivity) {
        // 默认只提示"可能改变应用状态"的写操作,且仅在成功时。
        guard activity.isMutation, activity.isSuccess else { return }

        currentToast = Toast(
            title: activity.description ?? activity.path,
            detail: "\(activity.method)  ·  \(Self.shortPluginID(activity.pluginID))  ·  \(activity.statusCode)"
        )

        // 重启消失计时器:实现"替换式"节流。
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            self?.currentToast = nil
        }
    }

    /// 把完整插件 ID 简化为末段,如 `com.coffic.lumi.plugin.theme-manager` → `theme-manager`。
    private static func shortPluginID(_ id: String) -> String {
        id.split(separator: ".").last.map(String.init) ?? id
    }
}

// MARK: - Toast Overlay View

/// 挂在主窗口顶部的 Web 请求 toast 覆盖层。
///
/// 通过 `.onLumiWebRequestReceived` 订阅事件,命中"写操作成功"时显示一条瞬时提示,
/// 让用户知道"App 刚被一次网络请求驱动着做了某件事"。
struct WebRequestToastOverlay: View {
    @StateObject private var model = WebRequestToastModel()

    var body: some View {
        Group {
            if let toast = model.currentToast {
                toastView(toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: model.currentToast)
        .onLumiWebRequestReceived { activity in
            model.handle(activity)
        }
    }

    private func toastView(_ toast: WebRequestToastModel.Toast) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(toast.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: 380)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .help("此操作由本地 Web 服务(127.0.0.1)的请求触发")
    }
}
