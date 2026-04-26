import SwiftUI

enum AppRoute: Equatable {
    case main
    case watchChecklist

    static func from(url: URL) -> AppRoute {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        if host == "watch", path.contains("checklist") {
            return .watchChecklist
        }
        return .main
    }
}

@main
struct OutingCheckerApp: App {
    @State private var route: AppRoute = .main

    var body: some Scene {
        WindowGroup {
            ContentView(route: route)
                .onOpenURL { url in
                    route = AppRoute.from(url: url)
                }
        }
    }
}
