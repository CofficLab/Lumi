#if !os(macOS)
import FactoryBookletMakerIOS
import SwiftUI
import UniformTypeIdentifiers

struct BookletMakerIOSApp: App {
    @StateObject private var feature = FactoryBookletMakerIOS.makeMobileFeature()
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                feature.makeContentView()
                    .navigationTitle(feature.documentName)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                isImporterPresented = true
                            } label: {
                                Label("Open PDF", systemImage: "doc.badge.plus")
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isSettingsPresented = true
                            } label: {
                                Label("Settings", systemImage: "slider.horizontal.3")
                            }
                        }
                    }
                    .fileImporter(
                        isPresented: $isImporterPresented,
                        allowedContentTypes: [.pdf],
                        allowsMultipleSelection: false
                    ) { result in
                        guard case let .success(urls) = result, let url = urls.first else { return }
                        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
                        Task { @MainActor in
                            await feature.loadPDF(url)
                            if didStartSecurityScope {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }
                    }
                    .sheet(isPresented: $isSettingsPresented) {
                        NavigationStack {
                            ScrollView {
                                feature.makeSettingsView()
                                    .padding(20)
                            }
                            .navigationTitle("Settings")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { isSettingsPresented = false }
                                }
                            }
                        }
                    }
            }
        }
    }
}
#endif
