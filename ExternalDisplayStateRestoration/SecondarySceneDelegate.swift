import UIKit

/// 由通知触发创建的次级场景的 delegate。
/// 它和主场景同属一个 App 进程，共享 AppData 等全局状态。
class SecondarySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var observerToken: NSObjectProtocol?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = SecondaryViewController()
        self.window = window
        window.makeKeyAndVisible()
        print("[SecondaryScene] 已连接（由通知触发创建）")

        // 监听「返回主场景」通知；用 [weak scene] 避免循环引用
        observerToken = NotificationCenter.default.addObserver(
            forName: SceneSwitchNotification.backToMain, object: nil, queue: .main
        ) { [weak self, weak scene] _ in
            guard let scene = scene else { return }
            self?.returnToMainScene(scene: scene)
        }
    }

    /// 切回主场景：先激活主场景 session，再销毁自身 session
    private func returnToMainScene(scene: UIScene) {
        if let mainSession = UIApplication.shared.openSessions.first(where: {
            $0.configuration.name == "Main Configuration"
        }) {
            UIApplication.shared.requestSceneSessionActivation(
                mainSession, userActivity: nil, options: nil
            ) { error in
                if let error { print("[Secondary] 激活主场景失败: \(error)") }
            }
        }
        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil) { error in
            if let error { print("[Secondary] 销毁自身场景失败: \(error)") }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let token = observerToken { NotificationCenter.default.removeObserver(token) }
        AppData.shared.visitCount += 1
        print("[SecondaryScene] 已断开并销毁")
    }
}
