//
//  SceneAudioController.swift
//  Open Wallpaper Engine
//
//  Plays audio embedded in Wallpaper Engine scene packages.
//

import AVFoundation
import Foundation

struct SceneAudioPlaybackState: Equatable {
    var playRate: Float
    var volume: Float
    var isSleeping: Bool

    var shouldPlayAudio: Bool {
        playRate > 0 && !isSleeping
    }

    var shouldAnimateScene: Bool {
        playRate > 0 && !isSleeping
    }

    var effectivePlayerRate: Float {
        min(max(playRate, 0.5), 2)
    }

    var effectiveVolume: Float {
        min(max(volume, 0), 1)
    }
}

final class SceneAudioController {
    private var player: AVAudioPlayer?

    private(set) var playbackState = SceneAudioPlaybackState(
        playRate: 1,
        volume: 1,
        isSleeping: false
    )

    var hasAudio: Bool {
        player != nil
    }

    func load(data: Data?) {
        stop()
        guard let data, !data.isEmpty else { return }

        do {
            let player = try AVAudioPlayer(data: data)
            player.numberOfLoops = -1
            player.enableRate = true
            player.prepareToPlay()
            self.player = player
            applyPlaybackState()
        } catch {
            NSLog("[SceneAudio] Failed to decode packaged audio: %@", "\(error)")
        }
    }

    func update(playRate: Float, volume: Float) {
        playbackState.playRate = playRate
        playbackState.volume = volume
        applyPlaybackState()
    }

    func setSleeping(_ isSleeping: Bool) {
        playbackState.isSleeping = isSleeping
        applyPlaybackState()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func applyPlaybackState() {
        guard let player else { return }

        player.volume = playbackState.effectiveVolume
        player.rate = playbackState.effectivePlayerRate

        if playbackState.shouldPlayAudio {
            if !player.isPlaying {
                player.play()
            }
        } else if player.isPlaying {
            player.pause()
        }
    }
}
