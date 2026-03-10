import Foundation
import Observation
import os

@MainActor @Observable
public final class Settings {
    public let voiceInput: VoiceInputSettings
    public let hotkey: HotkeySettings
    public let script: ScriptSettings
    public let replacement: ReplacementSettings
    public let history: HistorySettings
    public let paste: PasteSettings
    public let volumeDucking: VolumeDuckingSettings

    public init(defaults: UserDefaults = .standard) {
        voiceInput = VoiceInputSettings(defaults: defaults)
        hotkey = HotkeySettings(defaults: defaults)
        script = ScriptSettings(defaults: defaults)
        replacement = ReplacementSettings(defaults: defaults)
        history = HistorySettings(defaults: defaults)
        paste = PasteSettings(defaults: defaults)
        volumeDucking = VolumeDuckingSettings(defaults: defaults)
    }
}
