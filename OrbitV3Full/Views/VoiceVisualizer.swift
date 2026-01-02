import SwiftUI

struct VoiceVisualizer: View {
    @EnvironmentObject var backendService: BackendService
    @State private var isListening = false
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.Colors.cyanGlow, lineWidth: 1)
                )
            
            // Waveform
            Canvas { context, size in
                let path = createWaveformPath(in: size, data: backendService.audioLevels)
                context.stroke(
                    path,
                    with: .color(Theme.Colors.cyanPrimary),
                    lineWidth: 2
                )
            }
            .padding(.horizontal, 16)
            
            // Transcription overlay
            if backendService.orbState == .listening || isListening {
                Text("Listening...")
                    .font(Theme.Fonts.rajdhani(14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .onTapGesture {
            isListening.toggle()
            // Optional: trigger manual listening on backend if needed
            // backendService.sendVoiceCommand("START LISTENING") 
        }
    }
    
    private func createWaveformPath(in size: CGSize, data: [Double]) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let sliceWidth = size.width / CGFloat(data.count)
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * sliceWidth
            // Value is 0-1. Center it.
            let amplitude = CGFloat(value) * size.height
            let _ = (size.height / 2) - (amplitude / 2) // Simple centering logic or use as height
            
            // Let's make it look like a symmetric wave
            let yTop = (size.height / 2) - (amplitude * 0.8)
            let yBottom = (size.height / 2) + (amplitude * 0.8)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: yTop))
            } else {
                path.move(to: CGPoint(x: x, y: yTop))
                path.addLine(to: CGPoint(x: x, y: yBottom))
            }
        }
        
        return path
    }
}

#Preview {
    VoiceVisualizer()
        .frame(width: 600, height: 80)
        .padding()
        .background(Theme.Colors.background)
}
