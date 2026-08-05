import SwiftUI

struct ContentView: View {
    // @SceneStorage 自动借助底层 scene session 复用机制恢复状态，
    // 杀掉 App 再打开，值仍在（对应 UIKit 版手动 stateRestorationActivity）
    @SceneStorage("counter") private var counter = 0
    @SceneStorage("draftText") private var draftText = "输入文字，杀掉 App 再回来，文字还在"
    @SceneStorage("selectedSegment") private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("计数器") {
                    HStack {
                        Text("计数: \(counter)")
                        Spacer()
                        Button("+1") { counter += 1 }
                    }
                }
                Section("草稿") {
                    TextEditor(text: $draftText)
                        .frame(height: 120)
                }
                Section("选择") {
                    Picker("颜色", selection: $selectedSegment) {
                        Text("红").tag(0)
                        Text("绿").tag(1)
                        Text("蓝").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("主场景 · 状态恢复 (SwiftUI)")
        }
    }
}
