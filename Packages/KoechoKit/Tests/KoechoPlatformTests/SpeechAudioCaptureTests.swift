@preconcurrency import AVFoundation
import KoechoCore
import Testing

@testable import KoechoPlatform

struct SpeechAudioCaptureTests {
  @Test(arguments: [(24000.0, AVAudioChannelCount(1)), (48000.0, AVAudioChannelCount(2))])
  func captureUsesHardwareRateAndChannels(rate: Double, channels: AVAudioChannelCount) throws {
    let hardware = try #require(AVAudioFormat(
      commonFormat: .pcmFormatInt16, sampleRate: rate, channels: channels, interleaved: true))
    let staleClient = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
    let capture = try SpeechAudioCaptureFormat.make(hardware: hardware)
    #expect(capture != staleClient)
    #expect(capture.sampleRate == rate)
    #expect(capture.channelCount == channels)
    #expect(capture.commonFormat == .pcmFormatFloat32)
  }

  @Test func matchingHardwareKeepsCaptureFormat() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
    let capture = try SpeechAudioCaptureFormat.make(hardware: format)
    #expect(capture == format)
  }

  @Test func invalidHardwareFails() throws {
    let invalid = try #require(AVAudioFormat(standardFormatWithSampleRate: 0, channels: 1))
    #expect(throws: VoiceInputEngineError.noAudioInputDevice) {
      try SpeechAudioCaptureFormat.make(hardware: invalid)
    }
  }

  @Test(arguments: [24000.0, 44100.0, 48000.0, 96000.0])
  func consecutivePCMInputsAreNotRepeated(rate: Double) throws {
    let input = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
    let output = try #require(AVAudioFormat(
      commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false))
    let converter = try SpeechAudioConverter(input: input, output: output)
    // Alternating constant blocks expose an input mistakenly retained or supplied twice.
    for sign: Float in [1, -1, 1, -1] {
      let buffer = try #require(AVAudioPCMBuffer(pcmFormat: input, frameCapacity: 4096))
      buffer.frameLength = 4096
      let samples = try #require(buffer.floatChannelData?[0])
      for index in 0..<4096 { samples[index] = sign * 0.25 }
      let converted = try #require(converter.convert(buffer))
      #expect(converted.format == output)
      #expect(converted.frameLength > 0)
      #expect(Double(converted.frameLength) <= ceil(4096 * 16000 / rate))
      let convertedSamples = try #require(converted.int16ChannelData?[0])
      // Ignore the resampler's transition/priming region at the front of each block.
      let tail = Int(converted.frameLength) / 2..<Int(converted.frameLength)
      #expect(tail.allSatisfy { Float(convertedSamples[$0]) * sign > 4000 })
    }
  }

  @Test func matchingPCMBypassesConversion() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
    let converter = try SpeechAudioConverter(input: format, output: format)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32))
    #expect(converter.convert(buffer) == nil)
    buffer.frameLength = 32
    #expect(converter.convert(buffer) === buffer)
  }
}
