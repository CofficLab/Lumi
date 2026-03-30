import Foundation

/// 线程安全的元数据持有者
actor MetadataHolder {
    private var _metadata: RequestMetadata?
    
    func set(_ metadata: RequestMetadata) {
        _metadata = metadata
    }
    
    func get() -> RequestMetadata? {
        _metadata
    }
}
