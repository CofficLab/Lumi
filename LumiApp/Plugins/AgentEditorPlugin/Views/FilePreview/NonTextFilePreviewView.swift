import SwiftUI
import UniformTypeIdentifiers

/// 非文本文件预览视图
///
/// 根据文件 UTType 自动选择对应的预览方式：
/// - 图片 → `ImageFilePreviewView`（原生图片显示）
/// - PDF → `PDFFilePreviewView`（PDFKit 渲染）
/// - 其他 → `AnyFilePreviewView`（QuickLook 通用预览）
struct NonTextFilePreviewView: View {

    let fileURL: URL

    var body: some View {
        let fileType = fileURL.pathExtension.lowercased()
        let utType = UTType(filenameExtension: fileType)

        Group {
            if utType?.conforms(to: .image) == true {
                ImageFilePreviewView(fileURL)
            } else if utType?.conforms(to: .pdf) == true || fileType == "pdf" {
                PDFFilePreviewView(fileURL)
            } else {
                AnyFilePreviewView(fileURL)
            }
        }
    }
}
