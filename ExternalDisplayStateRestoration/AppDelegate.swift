import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification, object: nil, queue: .main
        ) { [weak self] note in self?.handleScreenDidConnect(note) }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification, object: nil, queue: .main
        ) { _ in print("[App] 外部屏幕已断开，external scene 将被系统销毁") }
        return true
    }

    private func handleScreenDidConnect(_ note: Notification) {
        guard let screen = note.object as? UIScreen else { return }
        print("[App] 外部屏幕已连接：\(screen.nativeBounds.width) x \(screen.nativeBounds.height)")
        let activity = NSUserActivity(activityType: "com.demo.externalDisplay")
        UIApplication.shared.requestSceneSessionActivation(
            nil, userActivity: activity, options: nil
        ) { error in
            if let error { print("[App] 请求 external scene 失败: \(error)") }
        }
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("[App] scene session 被销毁：\(sceneSessions.count)")
    }
}
