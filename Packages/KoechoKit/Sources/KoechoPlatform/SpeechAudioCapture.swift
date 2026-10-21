@preconcurrency import AVFoundation
import KoechoCore

/// Chooses the client PCM format without asking the input device to resample.
enum SpeechAudioCaptureFormat {
  static func make(hardware: AVAudioFormat) throws -> AVAudioFormat {
    guard hardware.sampleRate.isFinite, hardware.sampleRate > 0, hardware.channelCount > 0,
      let capture = AVAudioFormat(
        standardFormatWithSampleRate: hardware.sampleRate, channels: hardware.channelCount)
    else { throw VoiceInputEngineError.noAudioInputDevice }
    return capture
  }
}

/// One converter belongs to one capture stream, including its resampling state.
final class SpeechAudioConverter: Sendable {
  private let converter: AVAudioConverter?
  private let outputFormat: AVAudioFormat

  init(input: AVAudioFormat, output: AVAudioFormat) throws {
    outputFormat = output
    if input == output {
      converter = nil
    } else {
      guard let converter = AVAudioConverter(from: input, to: output) else {
        throw VoiceInputEngineError.audioFormatConversionNotSupported
      }
      self.converter = converter
    }
  }

  func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let converter else { return buffer.frameLength > 0 ? buffer : nil }
    let capacity = AVAudioFrameCount(
      ceil(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate))
    guard capacity > 0,
      let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity)
    else { return nil }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      guard !supplied else {
        inputStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return buffer
    }
    guard error == nil, status != .error, output.frameLength > 0 else { return nil }
    return output
  }
}
