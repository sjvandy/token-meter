import SwiftUI

struct ContentView: View {
    let store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Code Usage")
                .font(.headline)

            if let snapshot = store.snapshot {
                if let session = snapshot.fiveHour {
                    UsageRow(title: "Session (5 hr)", window: session)
                }
                if let weekly = snapshot.sevenDay {
                    UsageRow(title: "Weekly", window: weekly)
                }
            } else if store.errorMessage == nil {
                ProgressView().controlSize(.small)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                if let updated = store.lastUpdated {
                    Text("Updated \(updated, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { Task { await store.refresh() } }
                    .disabled(store.isLoading)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 280)
    }
}

private struct UsageRow: View {
    let title: String
    let window: UsageWindow

    private var tint: Color {
        switch window.utilization {
        case 90...: .red
        case 75...: .orange
        default: .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(window.utilization.rounded()))%")
                    .monospacedDigit()
                    .bold()
            }
            ProgressView(value: min(max(window.utilization, 0), 100), total: 100)
                .tint(tint)
            if let resetsAt = window.resetsAt {
                Text("Resets \(resetsAt, format: .relative(presentation: .named)) (\(resetsAt, format: .dateTime.weekday().hour().minute()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView(store: UsageStore())
}
