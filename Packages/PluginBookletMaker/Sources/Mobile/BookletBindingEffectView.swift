#if os(iOS)
import SwiftUI

/// 装订效果演示：bookletFold 展示纸张沿中缝折叠的动画；
/// simplePair 展示并排摆放示意。
struct BookletBindingEffectView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var foldAngle: Double = 0 // degrees, 0 = open, 180 = folded
    @State private var isPlaying = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                demoPaper
                controls
                explanation
            }
            .padding(16)
        }
        .onDisappear { isPlaying = false }
    }

    // MARK: - Demo

    @ViewBuilder
    private var demoPaper: some View {
        if viewModel.settings.layout == .bookletFold {
            foldedDemo
        } else {
            simplePairDemo
        }
    }

    private var foldedDemo: some View {
        VStack(spacing: 8) {
            ZStack {
                // 背面：折叠后露出的外侧
                Color.white
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary.opacity(0.4))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                // 左页：绕中缝旋转
                pageSide(page: 1)
                    .rotation3DEffect(
                        .degrees(-foldAngle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        anchorZ: 0,
                        perspective: 0.35
                    )

                // 右页：固定
                HStack {
                    Spacer()
                    pageSide(page: 2)
                        .frame(width: 100)
                }
            }
            .frame(height: 210)
            .padding(.horizontal, 60)
            .accessibilityLabel(BookletLocalization.string("Fold animation"))
        }
    }

    private func pageSide(page: Int) -> some View {
        PDFDocumentPageView(
            documentURL: viewModel.currentDocument.url,
            pageNumber: page
        )
        .frame(width: 100, height: 140)
    }

    private var simplePairDemo: some View {
        HStack(spacing: 2) {
            pageSide(page: 1)
            pageSide(page: 2)
        }
        .frame(height: 180)
        .overlay(alignment: .bottom) {
            Text(BookletLocalization.string("Side by side on one sheet"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(.bar, in: Capsule())
        }
        .accessibilityLabel(BookletLocalization.string("Side-by-side demo"))
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            if viewModel.settings.layout == .bookletFold {
                HStack {
                    Text(BookletLocalization.string("Fold angle"))
                    Spacer()
                    Text(BookletLocalization.string("%lld°", Int64(foldAngle)))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $foldAngle, in: 0 ... 180, step: 5)
                    .accessibilityLabel(BookletLocalization.string("Fold angle"))

                Button {
                    playFoldAnimation()
                } label: {
                    Label(
                        isPlaying
                            ? BookletLocalization.string("Animating…")
                            : BookletLocalization.string("Play fold"),
                        systemImage: isPlaying ? "stop.circle" : "play.circle"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isPlaying)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func playFoldAnimation() {
        isPlaying = true
        withAnimation(.linear(duration: 1.6)) {
            foldAngle = 180
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.7))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 1.6)) {
                foldAngle = 0
            }
            try? await Task.sleep(for: .seconds(1.7))
            isPlaying = false
        }
    }

    // MARK: - Explanation

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BookletLocalization.string("How the pages come together"))
                .font(.subheadline.weight(.semibold))
            Text(explanationText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var explanationText: String {
        switch viewModel.settings.layout {
        case .bookletFold:
            return BookletLocalization.string(
                "Two source pages share one physical sheet, front and back. "
                + "Fold the sheet along the centre line and read pages in order."
            )
        case .simplePair:
            return BookletLocalization.string(
                "Two source pages are printed side by side on one sheet "
                + "without folding."
            )
        }
    }
}
#endif
