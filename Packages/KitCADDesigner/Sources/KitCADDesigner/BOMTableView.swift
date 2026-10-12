import SwiftUI

private typealias L = CADDesignerLocalization

/// 物料清单表格 + 切割优化结果展示。
struct BOMTableView: View {
    @ObservedObject var viewModel: CADWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L.string("Bill of Materials"))
                    .font(.headline)
                Spacer()
                if let report = viewModel.bomReport {
                    Text("\(report.totalComponentCount) · \(String(format: "%.2f", report.totalWeight)) kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                if let report = viewModel.bomReport, !report.items.isEmpty {
                    bomTable(report)
                    cutOptimizationSection()
                } else {
                    Text(L.string("No components"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear { viewModel.refreshBOM() }
    }

    private func bomTable(_ report: BOMReport) -> some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                tableHeader(L.string("Part Number"), width: 180)
                tableHeader(L.string("Description"), width: 240)
                tableHeader(L.string("Length"), width: 80, alignment: .trailing)
                tableHeader(L.string("Quantity"), width: 60, alignment: .trailing)
                tableHeader(L.string("Weight"), width: 70, alignment: .trailing)
                tableHeader(L.string("Material"), width: 80)
            }
            Divider()

            ForEach(report.items) { item in
                HStack(spacing: 0) {
                    tableCell(item.partNumber, width: 180)
                    tableCell(item.description, width: 240)
                    tableCell(item.length > 0 ? "\(Int(item.length))" : "—", width: 80, alignment: .trailing)
                    tableCell("\(item.quantity)", width: 60, alignment: .trailing)
                    tableCell(String(format: "%.2f", item.weight), width: 70, alignment: .trailing)
                    tableCell(item.material, width: 80)
                }
                Divider()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func cutOptimizationSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.string("Cut Optimization"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 8) {
                    Text(L.string("Stock Length"))
                        .font(.caption)
                    TextField("", value: $viewModel.stockLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                    Button(L.string("Optimize")) {
                        viewModel.runCutOptimization()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let result = viewModel.cutResult {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(result.stockCount) × \(Int(viewModel.stockLength))mm 原料 · 总利用率 \(String(format: "%.1f%%", result.totalUtilization * 100))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(result.stocks.enumerated()), id: \.offset) { index, stock in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("原料 #\(index + 1)：余 \(Int(stock.remainder))mm · 利用率 \(String(format: "%.1f%%", stock.utilization * 100))")
                                .font(.caption2.monospacedDigit())
                            Text(stock.cuts.map { "\(Int($0))" }.joined(separator: " + ") + " mm")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(6)
                        .background(Color.accentColor.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tableHeader(_ title: String, width: CGFloat, alignment: TextAlignment = .leading) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: frameAlignment(alignment))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }

    private func tableCell(_ value: String, width: CGFloat, alignment: TextAlignment = .leading) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: width, alignment: frameAlignment(alignment))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }

    private func frameAlignment(_ alignment: TextAlignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
