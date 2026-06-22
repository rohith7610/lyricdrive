import SwiftUI
import SwiftData
import CarPlay

@main
struct LyricDriveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container = AppDependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container.lyricsViewModel)
                .environment(container.searchViewModel)
                .environment(container.favoritesViewModel)
                .environment(container.settingsViewModel)
                .environment(container.themeManager)
                .modelContainer(container.modelContainer)
                .preferredColorScheme(container.settingsViewModel.colorSchemeOverride)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppDependencyContainer.shared.configure(application: application)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            config.sceneClass = CPTemplateApplicationScene.self
            return config
        }

        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
