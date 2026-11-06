import SwiftUI

/// Four-bar RSSI indicator matching the Android `SignalBars` composable.
struct SignalBars: View {
    /// 0 (weak) .. 4 (excellent).
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < level ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(6 + index * 3))
            }
        }
        .frame(height: 15, alignment: .bottom)
        .accessibilityLabel(Text("Signal strength \(level) of 4"))
    }
}
