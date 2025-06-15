import SwiftUI

/// Reactive waveform view that displays a smooth bar animation driven by the incoming audio level.
/// The view keeps a short history of recent levels so that bars animate from right-to-left similar to
/// classic voice visualisers.
struct WaveformView: View {
    /// Current audio level (0.0 – 1.0). Typical RMS levels coming from `AudioManager` are very small
    /// (≈0.000…-0.02). We multiply with a factor to obtain a perceptible height but still clamp the
    /// final value to the unit range.
    var level: Float
    
    /// Number of bars shown at once.
    private let barCount: Int = 30
    /// Internal history that is updated every time `level` changes.
    @State private var history: [CGFloat] = Array(repeating: 0, count: 30)
    
    var body: some View {
        GeometryReader { geo in
            let barSpacing: CGFloat = 2
            let availableWidth = geo.size.width - (CGFloat(barCount - 1) * barSpacing)
            let barWidth = max(1, availableWidth / CGFloat(barCount))
            
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(history.indices, id: \.self) { idx in
                    Capsule(style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: barWidth,
                               height: max(1, history[idx] * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onChange(of: level) { newLevel in
                // Map raw level (0–1) to visual height. We boost low levels for nicer visuals.
                let boosted = min(1.0, CGFloat(newLevel * 14)) // empiric multiplier
                withAnimation(.linear(duration: 0.05)) {
                    history.append(boosted)
                    if history.count > barCount {
                        history.removeFirst()
                    }
                }
            }
            // Keep the view updating even if the value remains identical for a while (e.g. silence).
            .onAppear {
                // Ensure history has the correct length after hot reloads.
                history = Array(repeating: 0, count: barCount)
            }
        }
    }
}

#if DEBUG
struct WaveformView_Previews: PreviewProvider {
    struct Demo: View {
        @State private var level: Float = 0.0
        var body: some View {
            VStack {
                WaveformView(level: level)
                    .frame(height: 60)
                    .padding()
                Slider(value: $level, in: 0...1)
            }
            .frame(width: 300)
        }
    }
    static var previews: some View { Demo() }
}
#endif 