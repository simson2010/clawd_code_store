import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let vc = MainViewController()
        window.rootViewController = vc
        self.window = window
        window.makeKeyAndVisible()

        let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity
        if let activity { vc.restore(from: activity) }
        print("[MainScene] 已连接（session: \(session.persistentIdentifier)）")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[MainScene] 已断开（session 保留，等待复用）")
    }
    func sceneDidBecomeActive(_ scene: UIScene) { print("[MainScene] active") }
    func sceneWillResignActive(_ scene: UIScene) { print("[MainScene] resign active") }
    func sceneDidEnterBackground(_ scene: UIScene) { print("[MainScene] background") }
    func sceneWillEnterForeground(_ scene: UIScene) { print("[MainScene] foreground") }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let vc = window?.rootViewController as? MainViewController else { return nil }
        let activity = NSUserActivity(activityType: "com.demo.stateRestoration")
        activity.userInfo = vc.snapshot()
        return activity
    }
}
