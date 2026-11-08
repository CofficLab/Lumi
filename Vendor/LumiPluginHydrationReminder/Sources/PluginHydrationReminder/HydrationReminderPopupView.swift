import SwiftUI

struct HydrationReminderPopupView: View {
    @ObservedObject private var manager = HydrationReminderManager.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                Text("Hydration", tableName: "HydrationReminder", bundle: .module)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                HydrationReminderControls()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Status", tableName: "HydrationReminder", bundle: .module)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                HydrationReminderStatusInfo()
            }
            Divider().padding(.horizontal, 12).padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text("Interval", tableName: "HydrationReminder", bundle: .module)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                HydrationIntervalPicker()
            }
        }
        .padding(.bottom, 8)
        .background(
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.05), Color.cyan.opacity(0.03), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                ZStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.04))
                        .rotationEffect(.degrees(-15))
                        .offset(x: 100, y: 40)
                }
            }
        )
        .clipped()
    }
}
