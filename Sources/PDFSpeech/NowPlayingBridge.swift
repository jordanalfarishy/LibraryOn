import Foundation
import MediaPlayer

@MainActor final class NowPlayingBridge {
    static let shared = NowPlayingBridge()

    private weak var player: SpeechPlayer?
    private var registered = false

    private init() {}

    func publish(_ player: SpeechPlayer, title: String, isPlaying: Bool) {
        registerCommands()
        self.player = player
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "LibraryOn",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        center.playbackState = isPlaying ? .playing : .paused
        setCommandsEnabled(true)
    }

    func setPlaying(_ isPlaying: Bool, for player: SpeechPlayer) {
        guard self.player === player else { return }
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    func clear(for player: SpeechPlayer) {
        guard self.player === player else { return }
        self.player = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        setCommandsEnabled(false)
    }

    private func registerCommands() {
        guard !registered else { return }
        registered = true
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.player?.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.player?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let player = self?.player else { return }
                if player.isPlaying { player.pause() } else { player.play() }
            }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.player?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.player?.previous() }
            return .success
        }
        setCommandsEnabled(false)
    }

    private func setCommandsEnabled(_ enabled: Bool) {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = enabled
        commands.pauseCommand.isEnabled = enabled
        commands.togglePlayPauseCommand.isEnabled = enabled
        commands.nextTrackCommand.isEnabled = enabled
        commands.previousTrackCommand.isEnabled = enabled
    }
}
