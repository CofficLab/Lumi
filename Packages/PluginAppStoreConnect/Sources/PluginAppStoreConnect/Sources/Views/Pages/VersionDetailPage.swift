import LumiUI
import SwiftUI

/// 版本详情页，可编辑和只读模式共用。
///
/// - `isEditable: true`：显示 BuildSection、可编辑截图和元数据编辑区
/// - `isEditable: false`：隐藏 BuildSection，截图只读，元数据只读展示
struct VersionDetailPage: View {
    @ObservedObject var viewModel: VM
    let version: AppStoreVersion
    let isEditable: Bool
    @Binding var importingScreenshots: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isEditable {
                        BuildSection(viewModel: viewModel, version: version)
                    }

                    ScreenshotsSection(
                        viewModel: viewModel,
                        importingScreenshots: isEditable ? $importingScreenshots : .constant(false),
                        isEditable: isEditable
                    )

                    if isEditable {
                        MetadataSection(viewModel: viewModel)
                    } else {
                        MetadataDisplaySection(localization: viewModel.selectedLocalization)
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
