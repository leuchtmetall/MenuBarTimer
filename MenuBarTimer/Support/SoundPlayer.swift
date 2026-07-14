//
//  SoundPlayer.swift
//  MenuBarTimer
//

import AppKit

/// Plays the sound that signals a timer has finished counting down.
enum SoundPlayer {
    static func playTimerCompleteSound() {
        NSSound(named: "Glass")?.play()
    }
}
