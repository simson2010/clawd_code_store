import Foundation

/// App 级别的共享单例：用来演示「次级场景连接到 App 主体」——
/// 所有 scene session 同属一个进程，天然共享同一份内存/状态。
final class AppData {
    static let shared = AppData()
    private init() {}

    var message = "来自 App 主体的共享数据"
    var visitCount = 0
}
