import SwiftUI

@main
struct OutingCheckerWidget_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    var body: some View {
        if #available(watchOS 9.0, *) {
            NavigationStack {
                ContentView()
            }
        } else {
            NavigationView {
                ContentView()
            }
        }
    }
}
