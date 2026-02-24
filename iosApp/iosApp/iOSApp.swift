import SwiftUI
import ComposeApp
import UIKit
import CarPlay

/// Tracks Koin/KMP initialization state for CarPlay.
/// ContentView triggers MainViewController which calls initKoin on first render.
enum KmpState {
    static var isReady = false
    static let readyNotification = Notification.Name("KMPReadyNotification")
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
            let config = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        return config
    }
}

@main
struct iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Keep a strong reference to the player
    // Using NativeAudioController with swift-opus and libFLAC for decoding
    private let player = NativeAudioController()

    init() {
        // Register the Swift implementation with Kotlin
        PlatformPlayerProvider.shared.player = player

        // Initialize NowPlayingManager early to configure AudioSession
        _ = NowPlayingManager.shared

        // Required for apps to appear in Control Center
        // Must be called for remote control events to work
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Koin is initialized by MainViewController's configure block
                    // (called when ContentView first renders). Notify CarPlay.
                    KmpState.isReady = true
                    NotificationCenter.default.post(name: KmpState.readyNotification, object: nil)
                }
        }
    }
}
