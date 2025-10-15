import Foundation

/// Metadata for AlarmKit alarms
/// Contains custom data needed for StartSmart alarm functionality
struct AlarmMetadata: Codable {
    let traditionalSound: String
    let useTraditionalSound: Bool
    let useAIScript: Bool
    let hasCustomAudio: Bool
    let audioFilePath: String
    
    init(traditionalSound: String, useTraditionalSound: Bool, useAIScript: Bool, hasCustomAudio: Bool, audioFilePath: String) {
        self.traditionalSound = traditionalSound
        self.useTraditionalSound = useTraditionalSound
        self.useAIScript = useAIScript
        self.hasCustomAudio = hasCustomAudio
        self.audioFilePath = audioFilePath
    }
}
