import SwiftUI

@main struct MyApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            Image(systemName: "gauge.with.dots.needle.33percent")
            Text(store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
