import Foundation
import Observation

@Observable
final class UsageStore {
    private(set) var snapshot: UsageSnapshot?
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false

    private var refreshTask: Task<Void, Never>?

    /// Text shown next to the menu bar icon.
    var menuBarTitle: String {
        guard let session = snapshot?.fiveHour else { return "--" }
        return "\(Int(session.utilization.rounded()))%"
    }

    init() {
        startAutoRefresh()
    }

    func startAutoRefresh(interval: Duration = .seconds(60)) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await UsageService.fetch()
            errorMessage = nil
            lastUpdated = .now
        } catch {
            // Keep the last good snapshot visible; just surface the error.
            errorMessage = error.localizedDescription
        }
    }
}
