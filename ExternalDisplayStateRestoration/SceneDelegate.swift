import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var observerToken: NSObjectProtocol?

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

        // 收到「切换到次级场景」通知时，创建并切到新场景
        observerToken = NotificationCenter.default.addObserver(
            forName: SceneSwitchNotification.switchToSecondary, object: nil, queue: .main
        ) { [weak self] _ in
            self?.requestSecondaryScene()
        }
    }

    /// 请求系统创建一个次级场景 session（nil = 新建；携带 userActivity 让 AppDelegate 路由到 Secondary Configuration）
    private func requestSecondaryScene() {
        let activity = NSUserActivity(activityType: "com.demo.secondaryScene")
        activity.userInfo = ["from": "mainScene"]
        UIApplication.shared.requestSceneSessionActivation(
            nil, userActivity: activity, options: nil
        ) { error in
            if let error { print("[MainScene] 创建次级场景失败: \(error)") }
        }
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

    deinit {
        if let token = observerToken { NotificationCenter.default.removeObserver(token) }
    }
}
