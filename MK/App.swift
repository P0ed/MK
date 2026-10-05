import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
	func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		let configuration = UISceneConfiguration(name: "Main", sessionRole: session.role)
		configuration.delegateClass = SceneDelegate.self
		return configuration
	}
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
		guard let scene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: scene)
		window.rootViewController = ViewController()
		window.makeKeyAndVisible()
		self.window = window
		#if targetEnvironment(macCatalyst)
		scene.sizeRestrictions?.minimumSize = CGSize(width: 720, height: 420)
		#endif
	}

	func sceneWillResignActive(_ scene: UIScene) {
		(window?.rootViewController as? ViewController)?.pause(reason: "Game paused")
	}
}
