import MagicKit
import OSLog
import SwiftUI

struct LogoView: View {
    public enum Variant {
        case appIcon // For Dock, App Icon preview, Large displays
        case statusBar // For Menu Bar (Status Bar) - small, high contrast
        case about // For About window
        case general // Default general purpose
    }

    public enum Design: Int, CaseIterable {
        case smartLight = 1 // Logo1
        case elfAssistant = 2 // Logo2
        case multiFunction = 3 // Logo3
        case letterForm = 4 // Logo4
    }

    var variant: Variant = .general
    var design: Design = .smartLight

    var body: some View {
        GeometryReader { _ in
            Group {
                switch design {
                case .smartLight:
                    Logo1()
                case .elfAssistant:
                    Logo2()
                case .multiFunction:
                    Logo3()
                case .letterForm:
                    Logo4()
                }
            }
            .modifier(LogoVariantModifier(variant: variant))
        }
    }
}

struct LogoVariantModifier: ViewModifier {
    let variant: LogoView.Variant

    func body(content: Content) -> some View {
        switch variant {
        case .appIcon:
            content
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .background(Color.black.opacity(0.8))
        case .statusBar:
            content
                // Status bar optimized: higher contrast, no heavy shadows if possible
                // Since the logos are complex views, we might just scale them slightly
                // or trust the Logo implementation.
                // For now, we apply minimal modification as the inner logos are self-contained.
                .scaleEffect(0.9)
        case .about:
            content
                .shadow(radius: 5)
        case .general:
            content
        }
    }
}

#Preview("LogoView") {
    ScrollView {
        VStack {
            HStack {
                LogoView(variant: .general, design: .smartLight)
                    .frame(width: 250, height: 250)

                LogoView(variant: .appIcon, design: .smartLight)
                    .frame(width: 250, height: 250)
            }

            HStack {
                LogoView(variant: .about)
                    .frame(width: 250, height: 250)

                LogoView(variant: .statusBar, design: .smartLight)
                    .frame(width: 250, height: 250)
            }
        }
        .infinite()
    }
    .frame(height: 800)
    .frame(width: 600)
}

#Preview("LogoView - Snapshot") {
    LogoView(variant: .appIcon, design: .smartLight)
        .inMagicContainer(.init(width: 500, height: 500), scale: 1)
}
