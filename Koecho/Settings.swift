import Foundation
import os

@MainActor @Observable
final class Settings {
    let voiceInput: VoiceInputSettings
    let hotkey: HotkeySettings
    let script: ScriptSettings
    let replacement: ReplacementSettings
    let history: HistorySettings
    let paste: PasteSettings
    let volumeDucking: VolumeDuckingSettings

    init(defaults: UserDefaults = .standard) {
        voiceInput = VoiceInputSettings(defaults: defaults)
        hotkey = HotkeySettings(defaults: defaults)
        script = ScriptSettings(defaults: defaults)
        replacement = ReplacementSettings(defaults: defaults)
        history = HistorySettings(defaults: defaults)
        paste = PasteSettings(defaults: defaults)
        volumeDucking = VolumeDuckingSettings(defaults: defaults)
    }
}
