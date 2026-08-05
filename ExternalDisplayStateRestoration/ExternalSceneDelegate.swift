import UIKit

class ExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let screen = windowScene.screen
        print("[ExternalScene] 已连接外接屏 \(screen.nativeBounds.width) x \(screen.nativeBounds.height)")
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ExternalViewController()
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[ExternalScene] 已断开（外接屏移除）")
    }
}
