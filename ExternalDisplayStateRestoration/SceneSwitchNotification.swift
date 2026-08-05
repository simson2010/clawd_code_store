import Foundation

/// 场景切换用的通知名。
/// - switchToSecondary: 主场景收到后，创建并切换到「次级场景」
/// - backToMain:        次级场景收到后，销毁自身并切回「主场景」
enum SceneSwitchNotification {
    static let switchToSecondary = Notification.Name("com.demo.switchToSecondary")
    static let backToMain = Notification.Name("com.demo.backToMain")
}
