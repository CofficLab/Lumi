import SwiftUI

struct MarketingScreenshot05DatabaseTools: View {
    var body: some View {
        MarketingScreenshotStage(
            eyebrow: "Database Tools",
            title: "Query app data without leaving Lumi",
            subtitle: "Manage connections, write SQL and inspect result tables in the same desktop workbench."
        ) {
            MarketingMacWindow {
                MarketingToolPageShell(selectedIcon: "server.rack") {
                    VStack(spacing: 0) {
                        MarketingDatabaseToolMock()
                        MarketingStatusBar()
                    }
                }
            }
        }
    }
}

private struct MarketingDatabaseToolMock: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connections")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.top, 16)

                MarketingDatabaseConnectionRow(name: "Local App Store", type: "SQLite", selected: true)
                MarketingDatabaseConnectionRow(name: "Analytics Redis", type: "Redis")
                MarketingDatabaseConnectionRow(name: "Staging Postgres", type: "PostgreSQL")

                Spacer()

                HStack {
                    Image(systemName: "plus")
                    Text("Add Connection")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(red: 0.49, green: 0.44, blue: 1.00))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .padding(14)
            }
            .frame(width: 260)
            .background(Color(red: 0.128, green: 0.135, blue: 0.160))

            VStack(spacing: 0) {
                HStack {
                    Label("Local App Store", systemImage: "server.rack")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Circle().fill(Color(red: 0.19, green: 0.82, blue: 0.35)).frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.white.opacity(0.035))

                HStack(spacing: 16) {
                    MarketingDatabaseTableList()
                    MarketingSQLWorkspace()
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.092, green: 0.098, blue: 0.116))
            }
        }
    }
}

private struct MarketingDatabaseConnectionRow: View {
    let name: String
    let type: String
    var selected = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundStyle(selected ? Color(red: 0.49, green: 0.44, blue: 1.00) : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                Text(type)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(selected ? Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.22) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 10)
    }
}

private struct MarketingDatabaseTableList: View {
    var body: some View {
        MarketingCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Tables")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("12")
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)

                ForEach(["conversations", "messages", "tool_calls", "projects", "settings"], id: \.self) { table in
                    HStack {
                        Image(systemName: "tablecells")
                        Text(table)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(table == "messages" ? .white : .white.opacity(0.70))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(table == "messages" ? Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.22) : Color.black.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .frame(width: 250)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct MarketingSQLWorkspace: View {
    var body: some View {
        VStack(spacing: 14) {
            MarketingCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Query")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Run")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color(red: 0.49, green: 0.44, blue: 1.00))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 6) {
                        MarketingSQLLine("SELECT id, role, content, created_at")
                        MarketingSQLLine("FROM messages")
                        MarketingSQLLine("WHERE conversation_id = :current")
                        MarketingSQLLine("ORDER BY created_at DESC")
                        MarketingSQLLine("LIMIT 50;")
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .frame(height: 190)

            MarketingCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Results")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text("50 rows")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.white)

                    MarketingDatabaseResultTable()
                }
            }
        }
    }
}

private struct MarketingSQLLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white.opacity(0.88))
    }
}

private struct MarketingDatabaseResultTable: View {
    let rows = [
        ["1042", "assistant", "Updated the editor layout...", "12:48"],
        ["1041", "tool", "read_file ContentView.swift", "12:47"],
        ["1040", "user", "Refactor the bottom panel", "12:46"],
        ["1039", "assistant", "I found the relevant plugin", "12:44"],
        ["1038", "tool", "swift test --filter...", "12:43"]
    ]

    var body: some View {
        VStack(spacing: 0) {
            tableRow(["id", "role", "content", "created_at"], header: true)
            ForEach(rows, id: \.self) { row in
                tableRow(row)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func tableRow(_ values: [String], header: Bool = false) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(.system(size: 12, weight: header ? .semibold : .regular, design: index == 0 ? .monospaced : .default))
                    .foregroundStyle(header ? .white : .white.opacity(0.78))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(width: [76, 110, 360, 110][index], height: 36, alignment: .leading)
                    .background(header ? Color.white.opacity(0.07) : Color.black.opacity(index % 2 == 0 ? 0.11 : 0.06))
                    .border(Color.white.opacity(0.05), width: 0.5)
            }
        }
    }
}

#Preview("05 Database Tools") {
    MarketingScreenshot05DatabaseTools()
}
