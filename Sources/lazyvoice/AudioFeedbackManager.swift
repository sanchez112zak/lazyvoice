import Foundation
import AVFoundation

class AudioFeedbackManager {
    private var micOnPlayer: AVAudioPlayer?
    
    init() {
        setupAudioPlayers()
    }
    
    private func setupAudioPlayers() {
        // Get the main bundle's resource path
        guard let micOnURL = Bundle.main.url(forResource: "mic on", withExtension: "wav") else {
            print("AudioFeedbackManager: Could not find mic on audio file in bundle")
            return
        }
        
        do {
            // Create audio player
            micOnPlayer = try AVAudioPlayer(contentsOf: micOnURL)
            
            // Prepare player for immediate playback
            micOnPlayer?.prepareToPlay()
            
            // Set volume (adjust as needed, 0.0 to 1.0)
            micOnPlayer?.volume = 0.3
            
            print("AudioFeedbackManager: Audio player initialized successfully")
        } catch {
            print("AudioFeedbackManager: Failed to initialize audio player: \(error)")
        }
    }
    
    func playMicOnSound() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.micOnPlayer?.stop()
            self?.micOnPlayer?.currentTime = 0
            self?.micOnPlayer?.play()
        }
    }
    
    func setVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        micOnPlayer?.volume = clampedVolume
    }
} 