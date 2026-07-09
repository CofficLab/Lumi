import Foundation

/// BOM 行项（文档第 4.6 节）。
public struct BOMItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let partNumber: String
    public let description: String
    public let length: Double
    public let quantity: Int
    public let weight: Double
    public let material: String

    public init(
        id: String = UUID().uuidString,
        partNumber: String,
        description: String,
        length: Double,
        quantity: Int,
        weight: Double,
        material: String
    ) {
        self.id = id
        self.partNumber = partNumber
        self.description = description
        self.length = length
        self.quantity = quantity
        self.weight = weight
        self.material = material
    }
}

/// BOM 生成结果。
public struct BOMReport: Equatable, Sendable {
    public let items: [BOMItem]
    public let totalWeight: Double
    public let totalComponentCount: Int

    public init(items: [BOMItem], totalWeight: Double, totalComponentCount: Int) {
        self.items = items
        self.totalWeight = totalWeight
        self.totalComponentCount = totalComponentCount
    }
}

/// 物料清单生成器（文档第 4.6 节）。
///
/// 将文档中的组件聚合：相同型材规格 + 相同切割长度合并为一行；连接件按规格合并。
public struct BOMGenerator {
    public init() {}

    public func generate(from document: CADDocument, library: ComponentLibrary = .shared) -> BOMReport {
        var grouped: [String: (spec: ProfileSpec, length: Double, count: Int, weight: Double, material: String)] = [:]
        var connectorGrouped: [String: (spec: ConnectorSpec, count: Int, weight: Double)] = [:]

        var totalComponentCount = 0
        var totalWeight = 0.0

        for component in document.components {
            totalComponentCount += 1
            switch component {
            case .profile(let instance):
                guard let spec = library.profileSpec(id: instance.profileId) else { continue }
                let weight = instance.weight(spec: spec)
                totalWeight += weight
                let key = "\(spec.id)@\(Int(instance.length))"
                if var entry = grouped[key] {
                    entry.count += 1
                    entry.weight += weight
                    grouped[key] = entry
                } else {
                    grouped[key] = (spec, instance.length, 1, weight, instance.material)
                }
            case .connector(let instance):
                guard let spec = library.connectorSpec(id: instance.connectorId) else { continue }
                totalWeight += spec.unitWeight
                if var entry = connectorGrouped[spec.id] {
                    entry.count += 1
                    entry.weight += spec.unitWeight
                    connectorGrouped[spec.id] = entry
                } else {
                    connectorGrouped[spec.id] = (spec, 1, spec.unitWeight)
                }
            }
        }

        var items: [BOMItem] = grouped
            .values
            .sorted { $0.spec.id < $1.spec.id }
            .map { entry in
                BOMItem(
                    partNumber: entry.spec.id,
                    description: "\(entry.spec.sizeLabel) 欧标型材 × \(Int(entry.length))mm",
                    length: entry.length,
                    quantity: entry.count,
                    weight: entry.weight,
                    material: entry.material
                )
            }

        items += connectorGrouped
            .values
            .sorted { $0.spec.id < $1.spec.id }
            .map { entry in
                BOMItem(
                    partNumber: entry.spec.id,
                    description: entry.spec.name,
                    length: 0,
                    quantity: entry.count,
                    weight: entry.weight,
                    material: entry.spec.material
                )
            }

        return BOMReport(items: items, totalWeight: totalWeight, totalComponentCount: totalComponentCount)
    }
}
