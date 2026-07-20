import LumiKernel
import SwiftUI

/// Displays a fatal error screen when the app cannot continue running.
/// Modeled after Cisum's CrashedView.
struct CrashedView: View {
    var error: Error

    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack {
                Spacer(minLength: 20)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .scaledToFit()
                    .frame(maxHeight: 120)

                Spacer()

                VStack {
                    Text("Unable to continue")
                        .font(.title)
                        .padding(.bottom, 10)

                    GroupBox {
                        Text(String(describing: type(of: error)))
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                            .font(.title2)

                        Text("\(error.localizedDescription)")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.bottom, 10)

                        // Copy error details button
                        Button(action: {
                            copyErrorToClipboard()
                        }) {
                            HStack {
                                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundColor(isCopied ? .green : .blue)
                                Text(isCopied ? "Copied" : "Copy Error Details")
                                    .foregroundColor(isCopied ? .green : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .stroke(isCopied ? Color.green : Color.blue, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(isCopied ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCopied)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                    }.padding()

                    Spacer()

                    debugView

                    #if os(macOS)
                        Button {
                            NSApplication.shared.terminate(self)
                        } label: {
                            Text("Quit")
                        }
                        .controlSize(.extraLarge)

                        Spacer()
                    #endif
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.8))
    }

    var debugView: some View {
        VStack(spacing: 10) {
            Section(content: {
                GroupBox {
                    makeKeyValueItem(
                        key: String(localized: "App Support"),
                        // 崩溃屏自身不能 throw（否则崩溃屏二次崩溃）。
                        // makeDataRootDirectory() 已改为 throws，此处用 try? 降级；
                        // 解析失败时显示占位符，恰好说明环境异常。
                        value: makeDataRootDirectory()?.path(percentEncoded: false)
                            ?? "(unavailable)"
                    )
                }
            }, header: { makeTitle("Folders") })

            GroupBox {
                Text("Please quit and reopen the app, or check logs for more details.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private func makeTitle(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title).font(.headline).padding(.leading, 10)
            Spacer()
        }
    }

    private func makeKeyValueItem(key: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(key)
                Text(value)
                    .font(.footnote)
                    .opacity(0.8)
            }
            Spacer()
        }
        .padding(5)
    }

    /// Copy error details to clipboard
    private func copyErrorToClipboard() {
        Self.errorDetailsText(error).copy()

        withAnimation {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isCopied = false
            }
        }
    }

    private func makeDataRootDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }

    nonisolated static func errorDetailsText(_ error: Error) -> String {
        """
        Error type: \(String(describing: type(of: error)))
        Error description: \(error.localizedDescription)
        """
    }
}

// MARK: - Clipboard Helper

extension String {
    func copy() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self, forType: .string)
        #endif
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("CrashedView") {
        CrashedView(
            error: NSError(
                domain: "TestError",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "This is a test error for preview purposes"]
            )
        )
    }

    #Preview("CrashedView - Force Cast Error") {
        CrashedView(
            error: NSError(
                domain: "com.coffic.lumi.bootstrap",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not cast LumiCore.chatService to ChatService. Make sure LumiCore.setupChatBootstrap was called."]
            )
        )
    }
#endif
