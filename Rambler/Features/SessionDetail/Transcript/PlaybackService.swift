import Foundation
import AVFoundation
import Observation
import OSLog

@Observable
final class PlaybackService: NSObject, AVAudioPlayerDelegate {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0

    private let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "Playback")
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func load(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            currentTime = 0
        } catch {
            logger.error("Playback load failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func togglePlay() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let target = max(0, min(time, player.duration))
        player.currentTime = target
        currentTime = target
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = player.duration
            self.stopTimer()
        }
    }
}
