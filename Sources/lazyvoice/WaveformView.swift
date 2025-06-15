import SwiftUI

/// Ultra-smooth waveform with natural voice-responsive animation
struct WaveformView: View {
    var level: Float
    
    private let barCount: Int = 50
    @State private var history: [CGFloat] = Array(repeating: 0, count: 50)
    @State private var smoothHistory: [CGFloat] = Array(repeating: 0, count: 50)
    
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 0.8) {
                ForEach(smoothHistory.indices, id: \.self) { index in
                    let intensity = smoothHistory[index]
                    let barHeight = max(2, intensity * geo.size.height * 0.9)
                    let barWidth = (geo.size.width - (CGFloat(barCount - 1) * 0.8)) / CGFloat(barCount)
                    
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(
                            LinearGradient(
                                colors: getUltraSmoothColors(intensity: intensity),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth, height: barHeight)
                        .shadow(
                            color: getSmoothShadow(intensity: intensity),
                            radius: intensity * 3 + 1,
                            x: 0,
                            y: 0
                        )
                        .opacity(0.75 + intensity * 0.25)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onChange(of: level) { newLevel in
                updateSmoothBars(newLevel: newLevel)
            }
            .onAppear {
                history = Array(repeating: 0, count: barCount)
                smoothHistory = Array(repeating: 0, count: barCount)
            }
        }
    }
    
    private func getUltraSmoothColors(intensity: CGFloat) -> [Color] {
        if intensity < 0.15 {
            return [
                Color.cyan.opacity(0.4),
                Color.cyan.opacity(0.7)
            ]
        } else if intensity < 0.35 {
            return [
                Color.cyan.opacity(0.6),
                Color.cyan.opacity(0.9),
                Color.white.opacity(0.4)
            ]
        } else if intensity < 0.65 {
            return [
                Color.cyan.opacity(0.8),
                Color.white.opacity(0.7),
                Color.cyan.opacity(0.95),
                Color.blue.opacity(0.6)
            ]
        } else {
            return [
                Color.blue.opacity(0.7),
                Color.cyan.opacity(0.95),
                Color.white.opacity(0.95),
                Color.cyan.opacity(0.95),
                Color.blue.opacity(0.7)
            ]
        }
    }
    
    private func getSmoothShadow(intensity: CGFloat) -> Color {
        if intensity < 0.25 {
            return Color.cyan.opacity(0.4)
        } else if intensity < 0.55 {
            return Color.cyan.opacity(0.7)
        } else {
            return Color.white.opacity(0.6)
        }
    }
    
    private func updateSmoothBars(newLevel: Float) {
        let responsive = min(1.0, CGFloat(newLevel * 32))
        
        // Add new value to raw history
        history.append(responsive)
        if history.count > barCount {
            history.removeFirst()
        }
        
        // Create ultra-smooth interpolated values
        withAnimation(.easeOut(duration: 0.15)) {
            for i in 0..<barCount {
                let target = history[i]
                let current = smoothHistory[i]
                
                // Smooth interpolation for natural movement
                let smoothed = current + (target - current) * 0.4
                smoothHistory[i] = smoothed
            }
        }
    }
}

#if DEBUG
struct WaveformView_Previews: PreviewProvider {
    struct Demo: View {
        @State private var level: Float = 0.4
        var body: some View {
            ZStack {
                Color.black
                VStack(spacing: 20) {
                    WaveformView(level: level)
                        .frame(height: 40)
                        .padding()
                    
                    HStack {
                        Text("Level:")
                        Slider(value: $level, in: 0...1)
                        Text("\(Int(level * 100))%")
                    }
                    .foregroundColor(.white)
                    .padding()
                }
            }
            .frame(width: 400, height: 160)
        }
    }
    static var previews: some View { Demo() }
}
#endif 