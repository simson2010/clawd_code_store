import SwiftUI

struct ExternalView: View {
    var body: some View {
        ZStack {
            Color.black
            Text("这是外接屏显示的内容\n（手机屏仍显示主场景）")
                .foregroundStyle(.white)
                .font(.system(size: 48, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .ignoresSafeArea()
    }
}
