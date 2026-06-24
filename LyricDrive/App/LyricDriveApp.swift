import SwiftUI
import SwiftData

@main
@MainActor
struct LyricDriveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var container: AppDependencyContainer { AppDependencyContainer.shared }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container.lyricsViewModel)
                .environment(container.searchViewModel)
                .environment(container.favoritesViewModel)
                .environment(container.settingsViewModel)
                .environment(container.themeManager)
                .environment(container.tabRouter)
                .modelContainer(container.modelContainer)
                .preferredColorScheme(container.settingsViewModel.colorSchemeOverride)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppDependencyContainer.shared.configure(application: application)
        return true
    }
}
