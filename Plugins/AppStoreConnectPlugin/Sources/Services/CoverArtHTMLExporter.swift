import AppKit
import AppStorePromoKit
import Foundation

@MainActor
enum CoverArtHTMLExporter {
    enum ExportError: LocalizedError {
        case loadTimedOut
        case unexpectedImageSize(expected: ScreenshotDisplaySpec.Size, actualWidth: Int, actualHeight: Int)
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .loadTimedOut:
                return AppStoreConnectLocalization.string("Timed out while loading cover art HTML.")
            case .unexpectedImageSize(let expected, let actualWidth, let actualHeight):
                return AppStoreConnectLocalization.string(
                    "Exported image size %dx%d does not match expected %dx%d.",
                    actualWidth,
                    actualHeight,
                    expected.width,
                    expected.height
                )
            case .pngEncodingFailed:
                return AppStoreConnectLocalization.string("Failed to encode PNG.")
            }
        }
    }

    static func exportPNG(
        html: String,
        fileURL: URL?,
        expectedSize: ScreenshotDisplaySpec.Size,
        tolerance: Int = 1
    ) async throws -> Data {
        _ = tolerance
        let preset = AppStorePromoDisplayPreset(
            displayType: "APP_STORE_CONNECT_COVER_ART",
            family: .mac,
            width: expectedSize.width,
            height: expectedSize.height
        )
        do {
            return try await AppStorePromoHTMLExporter.exportPNG(
                html: html,
                fileURL: fileURL,
                preset: preset
            )
        } catch AppStorePromoExportError.loadTimedOut {
            throw ExportError.loadTimedOut
        } catch AppStorePromoExportError.unexpectedImageSize(_, _, let actualWidth, let actualHeight) {
            throw ExportError.unexpectedImageSize(
                expected: expectedSize,
                actualWidth: actualWidth,
                actualHeight: actualHeight
            )
        } catch {
            throw ExportError.pngEncodingFailed
        }
    }
}
