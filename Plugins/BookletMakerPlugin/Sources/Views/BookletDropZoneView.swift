import Foundation
import os
import SuperLogKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Booklet Drop Zone

/// Top section: a single drop zone that accepts a PDF, plus a small
/// summary of the loaded file.
struct BookletDropZoneView: View, SuperLog {

    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var isTargeted: Bool = false

    // MARK: - SuperLog Identity

    nonisolated static let emoji = "📥"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker.drop-zone"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isTargeted
                                  ? Color.accentColor.opacity(0.08)
                                  : Color.gray.opacity(0.04))
                    )

                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(BookletLocalization.string(
                        "Drop a PDF here or click to choose one"))
                        .font(.headline)
                    if let info = viewModel.inputInfo {
                        Text(BookletLocalization.string(
                            "%@ · %lld pages · %lld×%lld pt",
                            viewModel.inputURL?.lastPathComponent ?? "",
                            info.pageCount,
                            Int(info.firstPageSize.width),
                            Int(info.firstPageSize.height)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .frame(height: 140)
            .contentShape(Rectangle())
            .onTapGesture { presentOpenPanel() }
            .onDrop(of: [.pdf, .fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            if viewModel.hasInput {
                HStack {
                    Label(
                        BookletLocalization.string("Output: %lld sheets")
                            .replacingOccurrences(of: "%lld", with: "\(viewModel.expectedSheetCount)"),
                        systemImage: "rectangle.split.2x1"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button(BookletLocalization.string("Clear")) {
                        viewModel.clear()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Actions

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.loadPDF(url) }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        Self.logger.info("\(Self.t)📥 handleDrop called, registeredTypes: \(provider.registeredTypeIdentifiers)")
        
        // 方式 1: 尝试直接获取文件 URL（适用于 Finder 拖拽的文件）
        if provider.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
            Self.logger.info("\(Self.t)🔍 Trying loadFileRepresentation for com.adobe.pdf")
            
            provider.loadFileRepresentation(forTypeIdentifier: "com.adobe.pdf") { url, error in
                if let error = error {
                    Self.logger.warning("\(Self.t)❌ loadFileRepresentation failed: \(error.localizedDescription)")
                    return
                }
                
                guard let tempURL = url else {
                    Self.logger.warning("\(Self.t)❌ loadFileRepresentation returned nil URL")
                    return
                }
                
                Self.logger.info("\(Self.t)✅ Got temp file URL: \(tempURL.absoluteString)")
                Self.logger.info("\(Self.t)📄 Filename: \(tempURL.lastPathComponent)")
                
                // 关键：loadFileRepresentation 提供的临时文件在回调后会被清理
                // 必须立即复制到安全位置
                let fileName = tempURL.lastPathComponent
                let safeDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BookletMakerDrops", isDirectory: true)
                
                do {
                    // 确保目标目录存在
                    try FileManager.default.createDirectory(at: safeDir, withIntermediateDirectories: true)
                    
                    let safeURL = safeDir.appendingPathComponent(fileName)
                    
                    // 如果同名文件已存在，先删除
                    if FileManager.default.fileExists(atPath: safeURL.path) {
                        try FileManager.default.removeItem(at: safeURL)
                    }
                    
                    // 复制文件到安全位置
                    try FileManager.default.copyItem(at: tempURL, to: safeURL)
                    Self.logger.info("\(Self.t)✅ Copied to safe location: \(safeURL.absoluteString)")
                    
                    Task { @MainActor in
                        await viewModel.loadPDF(safeURL)
                    }
                } catch {
                    Self.logger.error("\(Self.t)❌ Failed to copy file: \(error.localizedDescription)")
                }
            }
            return true
        }
        
        Self.logger.warning("\(Self.t)❌ No compatible type found in provider")
        return false
    }
}
