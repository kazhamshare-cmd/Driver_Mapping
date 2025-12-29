import AVFoundation
import AudioToolbox

class SoundManager {
    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?

    // 音量設定（0.0〜1.0）- 最小限でリジェクト回避
    // 日本の規定には明確なdB基準はないが、聞こえる程度は必要
    private let shutterVolume: Float = 0.3  // シャッター音量（30%）
    private let recordingVolume: Float = 0.2  // 録画開始音量（20%）

    private init() {
        setupAudioSession()
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            // 他のアプリの音楽を止めないように設定
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Play Shutter Sound (写真撮影時)
    func playShutterSound() {
        // システムシャッター音を使用（日本のiPhoneでは音量調整不可＝確実にリジェクト回避）
        // SystemSoundID 1108 = カメラシャッター音
        AudioServicesPlaySystemSound(1108)
    }

    // MARK: - Play Recording Start Sound (録画開始時)
    func playRecordingStartSound() {
        // システム音を使用（短いビープ音）
        // SystemSoundID 1113 = 短いトーン音
        AudioServicesPlaySystemSound(1113)
    }

    // MARK: - Play Recording Stop Sound (録画終了時)
    func playRecordingStopSound() {
        // SystemSoundID 1114 = 別のトーン音
        AudioServicesPlaySystemSound(1114)
    }

    // MARK: - Alternative: Custom Sound with Volume Control
    // カスタム音声ファイルを使用する場合（音量調整可能）
    func playCustomSound(named: String, volume: Float) {
        guard let url = Bundle.main.url(forResource: named, withExtension: "wav") ??
                        Bundle.main.url(forResource: named, withExtension: "mp3") else {
            print("Sound file not found: \(named)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
}
