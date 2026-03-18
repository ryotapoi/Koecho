import SwiftUI

struct InputLevelMeter: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            Text("Input Level")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .animation(.linear(duration: 0.1), value: level)
            }
            .frame(height: 6)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
            )
        }
    }

    private var levelColor: Color {
        if level > 0.9 { .red }
        else if level > 0.7 { .yellow }
        else { .green }
    }
}
