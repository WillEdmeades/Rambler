import SwiftUI
import SwiftData

@main
struct RamblerApp: App {
    var body: some Scene {
        WindowGroup {
            SessionsListView()
        }
        .modelContainer(for: Recording.self)
    }
}
