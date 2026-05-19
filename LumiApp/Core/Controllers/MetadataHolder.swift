import Foundation
import HttpKit

/// 线程安全的元数据持有者
actor MetadataHolder {
    private var _metadata: HTTPRequestMetadata?
    
    func set(_ metadata: HTTPRequestMetadata) {
        _metadata = metadata
    }
    
    func get() -> HTTPRequestMetadata? {
        _metadata
    }
}
