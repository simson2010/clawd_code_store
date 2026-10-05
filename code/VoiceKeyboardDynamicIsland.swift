//
//  VoiceKeyboardDynamicIsland.swift
//  键盘语音输入完整链路代码片段
//
//  架构（三个 Target 各自取对应段落）：
//  ┌─────────────────┐   App Group 写入标记    ┌──────────────────┐
//  │ Keyboard Ext    │ ──────────────────────▶ │ Main App         │
//  │ (不能碰麦克风)   │                         │ (麦克风权限+录音)  │
//  └─────────────────┘                         └────────┬─────────┘
//         ▲                                              │ ActivityKit
//         │ 读取转写结果 + textDocumentProxy 上屏           ▼
//  ┌──────┴──────────┐                         ┌──────────────────┐
//  │ 用户目标输入框    │                         │ Widget Ext       │
//  └─────────────────┘                         │ (灵动岛录音状态)   │
//                                               └──────────────────┘
//
//  前置配置清单：
//  1. 主 App Info.plist:        NSMicrophoneUsageDescription, Supports Live Activities = YES
//  2. 主 App Capabilities:      App Groups (group.com.example.voicekb), Background Modes > Audio
//  3. Keyboard Ext Capabilities: App Groups (同一个 group)
//  4. Widget Ext:               无需 App Group（UI 由主 App 通过 ActivityKit 驱动）
//

import SwiftUI
import AVFoundation
import ActivityKit
import WidgetKit
import UIKit

// ============================================================
// MARK: - 0. 共享常量（三个 Target 共用，建议放共享 Framework）
// ============================================================

enum VoiceKB {
    static let appGroupID = "group.com.example.voicekb"

    // App Group 共享的 UserDefaults Key
    enum Key {
        static let recordRequest = "vk_record_request"   // 键盘 → 主 App：请求录音
        static let transcript    = "vk_transcript"        // 主 App → 键盘：转写结果
        static let state         = "vk_state"             // idle / recording / done
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
}

// ============================================================
// MARK: - 1. Widget Extension：灵动岛 Live Activity UI
// ============================================================

/// 实时活动数据模型（Widget Ext 和 Main App 都要引用）
struct RecordingAttributes: ActivityAttributes {
    // 动态数据（≤ 4KB，可编码）
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int   // 已录音时长
        var isPaused: Bool
        var audioLevel: Float     // 0~1，用于画波形
    }
    // 静态数据
    var sessionTitle: String
}

/// 灵动岛 + 锁屏 UI
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            // ---- 锁屏 / 无灵动岛机型的 Banner ----
            HStack {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "mic.circle.fill")
                    .foregroundStyle(.red)
                Text("录音中 \(formatTime(context.state.elapsedSeconds))")
                Spacer()
                Text("点击返回")
                    .font(.caption)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // ---- 扩展视图（长按展开）----
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill").foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedSeconds)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.sessionTitle).font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // 简易波形条
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: 60 * CGFloat(max(context.state.audioLevel, 0.05)), height: 6)
                            .foregroundStyle(.green)
                        Spacer()
                        Link(destination: URL(string: "voicekb://stop")!) {
                            Label("停止", systemImage: "stop.circle.fill")
                        }
                    }
                }
            } compactLeading: {
                // ---- 紧凑左：红点 ----
                Image(systemName: "mic.fill").foregroundStyle(.red)
            } compactTrailing: {
                // ---- 紧凑右：计时 ----
                Text(formatTime(context.state.elapsedSeconds))
                    .monospacedDigit().font(.caption2)
            } minimal: {
                // ---- 最小化圆点 ----
                Image(systemName: "mic.fill").foregroundStyle(.red)
            }
            .widgetURL(URL(string: "voicekb://recording"))
            .keylineTint(.red)
        }
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// ============================================================
// MARK: - 2. Main App：麦克风权限 + 录音 + 驱动灵动岛
// ============================================================

@MainActor
final class RecordingManager: ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: AVAudioRecorder?
    private var activity: Activity<RecordingAttributes>?
    private var meterTimer: Timer?
    private var startDate: Date?

    // ---------- 权限申请（iOS 17+ API）----------
    func ensureMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // ---------- 开始录音（可被键盘请求触发，见 checkKeyboardRequest）----------
    func startRecording() async {
        guard await ensureMicPermission() else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = VoiceKB.sharedContainerURL!.appendingPathComponent("voice_input.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,          // 16k 单声道，转写够用且文件小
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()

        startDate = Date()
        isRecording = true
        VoiceKB.sharedDefaults?.set("recording", forKey: VoiceKB.Key.state)

        startLiveActivity()
        startMetering()
    }

    // ---------- 停止录音 → 转写 → 写回 App Group 给键盘 ----------
    func stopRecording() async {
        recorder?.stop()
        meterTimer?.invalidate()
        isRecording = false

        let audioURL = VoiceKB.sharedContainerURL!.appendingPathComponent("voice_input.m4a")

        // 转写：此处替换为你的 ASR（SFSpeechRecognizer / 服务端 API）
        let text = await transcribe(url: audioURL)

        VoiceKB.sharedDefaults?.set(text, forKey: VoiceKB.Key.transcript)
        VoiceKB.sharedDefaults?.set("done", forKey: VoiceKB.Key.state)

        await endLiveActivity()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // ---------- 键盘请求检测：主 App 每次进前台时调用 ----------
    // 注意：iOS 26 已封死键盘直接 openURL，所以用"标记 + 进前台自动响应"模式
    func checkKeyboardRequest() {
        let d = VoiceKB.sharedDefaults
        if d?.string(forKey: VoiceKB.Key.recordRequest) == "start" {
            d?.removeObject(forKey: VoiceKB.Key.recordRequest)
            Task { await startRecording() }
        }
    }

    // ---------- Live Activity 生命周期 ----------
    private func startLiveActivity() {
        let attrs = RecordingAttributes(sessionTitle: "语音输入")
        let state = RecordingAttributes.ContentState(elapsedSeconds: 0, isPaused: false, audioLevel: 0)
        activity = try? Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil   // 纯本地更新；如需服务端更新传 .token
        )
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            recorder?.updateMeters()
            let level = pow(10, (recorder?.averagePower(forChannel: 0) ?? -60) / 20) // dB → 0~1
            let elapsed = Int(Date().timeIntervalSince(startDate ?? Date()))
            let state = RecordingAttributes.ContentState(
                elapsedSeconds: elapsed, isPaused: false, audioLevel: min(level, 1)
            )
            Task { await self.activity?.update(.init(state: state, staleDate: nil)) }
        }
    }

    private func endLiveActivity() async {
        let final = RecordingAttributes.ContentState(elapsedSeconds: 0, isPaused: true, audioLevel: 0)
        await activity?.end(.init(state: final, staleDate: nil),
                            dismissalPolicy: .after(.now + 2))
        activity = nil
    }

    // ---------- ASR 占位 ----------
    private func transcribe(url: URL) async -> String {
        // TODO: SFSpeechRecognizer 离线转写，或上传到自己的 ASR 服务
        // SFSpeechRecognizer 在【主 App】里是可用的（只是键盘扩展里不可用）
        return "这是转写后的文本"
    }
}

// ============================================================
// MARK: - 3. Keyboard Extension：触发 + 轮询结果 + 上屏
// ============================================================

final class KeyboardViewController: UIInputViewController {

    private var pollTimer: Timer?

    /// 用户点了键盘上的麦克风按钮
    @objc private func micButtonTapped() {
        // ❌ 不能在这里录音（键盘扩展拿不到麦克风）
        // ❌ 不能 openURL 拉起主 App（iOS 26 已彻底封死）
        // ✅ 写标记，提示用户切回主 App；主 App 进前台时自动开始录音
        VoiceKB.sharedDefaults?.set("start", forKey: VoiceKB.Key.recordRequest)
        showToastOnKeyboard("请切回 App 开始录音")

        // 开始轮询转写结果（用户切回键盘时立即拿到）
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollTranscript()
        }
    }

    private func pollTranscript() {
        let d = VoiceKB.sharedDefaults
        guard d?.string(forKey: VoiceKB.Key.state) == "done",
              let text = d?.string(forKey: VoiceKB.Key.transcript),
              !text.isEmpty else { return }

        // ✅ 通过 textDocumentProxy 把转写文本插入用户的输入框
        textDocumentProxy.insertText(text)

        // 清理状态
        d?.set("idle", forKey: VoiceKB.Key.state)
        d?.removeObject(forKey: VoiceKB.Key.transcript)
        pollTimer?.invalidate()
    }

    private func showToastOnKeyboard(_ msg: String) {
        let label = UILabel()
        label.text = msg
        label.font = .systemFont(ofSize: 13)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textColor = .white
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.frame = CGRect(x: 20, y: 8, width: view.bounds.width - 40, height: 30)
        view.addSubview(label)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { label.removeFromSuperview() }
    }
}

// ============================================================
// MARK: - 4. Main App 入口钩子（App / SceneDelegate）
// ============================================================
//
//  SwiftUI App 示例：
//
//  @main
//  struct VoiceKBApp: App {
//      @StateObject private var recorder = RecordingManager()
//      var body: some Scene {
//          WindowGroup {
//              ContentView()
//                  .onAppear { recorder.checkKeyboardRequest() }   // 前台即检查键盘请求
//                  .onOpenURL { url in                              // voicekb://stop 等
//                      if url.host == "stop" {
//                          Task { await recorder.stopRecording() }
//                      }
//                  }
//          }
//      }
//  }
//
// ============================================================
// MARK: - 已知边界（务必读）
// ============================================================
//  1. 键盘扩展内 AVAudioRecorder / SFSpeechRecognizer 必然失败 —— 官方禁区，无绕过方案
//  2. 键盘无法主动拉起主 App（iOS 26 起 responder-chain hack 报 NSOSStatusErrorDomain -54）
//     → 必须用户手动切换一次；可用"插入标记文本 [[OpenHostApp]]"让主 App 自动感知
//  3. Live Activity 最长 8 小时、同一 App 最多 5 个并发、更新 payload ≤ 4KB
//  4. Live Activity 扩展进程禁止网络/定位 —— 录音文件读写只能在主 App 进程完成
//  5. 后台持续录音需开 Background Modes > Audio；锁屏录音时灵动岛红点为系统行为
