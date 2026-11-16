import 'dart:math' as math;
import 'dart:typed_data';

/// High-performance converter for raw 16-bit PCM audio samples.
///
/// Translates between signed 16-bit PCM bytes (emitted by Phase 2 [AudioCaptureService])
/// and normalized 32-bit floating point buffers (required by on-device ONNX ASR engines).
class PCMConverter {
  const PCMConverter();

  /// Converts signed 16-bit little-endian PCM bytes into normalized 32-bit floats [-1.0, 1.0].
  ///
  /// Each 16-bit sample occupies 2 bytes.
  /// If the byte length is odd, the trailing dangling byte is safely ignored.
  static Float32List pcm16ToFloat32(Uint8List pcmBytes) {
    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount == 0) return Float32List(0);

    final byteData = ByteData.sublistView(pcmBytes);
    final floatList = Float32List(sampleCount);

    for (int i = 0; i < sampleCount; i++) {
      final sampleInt16 = byteData.getInt16(i * 2, Endian.little);
      // Normalize to [-1.0, 1.0]. 32768.0 matches standard audio DSP normalization.
      floatList[i] = sampleInt16 / 32768.0;
    }

    return floatList;
  }

  /// Converts normalized 32-bit floats [-1.0, 1.0] back into signed 16-bit little-endian PCM bytes.
  ///
  /// Clamps values outside [-1.0, 1.0] to prevent clipping distortion.
  static Uint8List float32ToPcm16(Float32List floatSamples) {
    final byteLength = floatSamples.length * 2;
    final byteData = ByteData(byteLength);

    for (int i = 0; i < floatSamples.length; i++) {
      final clamped = floatSamples[i].clamp(-1.0, 1.0);
      final int16Value = (clamped * 32767.0).round();
      byteData.setInt16(i * 2, int16Value, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  /// Computes Root Mean Square (RMS) energy of a 16-bit PCM buffer.
  /// Returns a value between 0.0 (total silence) and 1.0 (full scale square wave).
  static double computeRms(Uint8List pcmBytes) {
    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount == 0) return 0.0;

    final byteData = ByteData.sublistView(pcmBytes);
    double sumSquares = 0.0;

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little) / 32768.0;
      sumSquares += sample * sample;
    }

    return math.sqrt(sumSquares / sampleCount);
  }

  /// Computes the peak absolute 16-bit integer sample amplitude in the buffer [0, 32767].
  static int computePeakAmplitude(Uint8List pcmBytes) {
    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount == 0) return 0;

    final byteData = ByteData.sublistView(pcmBytes);
    int maxPeak = 0;

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little).abs();
      if (sample > maxPeak) {
        maxPeak = sample;
      }
    }
    return maxPeak;
  }

  /// Counts the total number of non-zero bytes in the PCM buffer.
  /// Useful to differentiate true digital zeroes from ambient or low-amplitude speech.
  static int countNonZeroBytes(Uint8List pcmBytes) {
    int count = 0;
    for (int i = 0; i < pcmBytes.length; i++) {
      if (pcmBytes[i] != 0) {
        count++;
      }
    }
    return count;
  }

  /// Computes the maximum Root Mean Square (RMS) energy across sliding 100ms windows (1600 samples at 16kHz).
  /// This prevents a long pause before or after speech from diluting vocal bursts.
  static double computeMaxWindowRms(Uint8List pcmBytes, {int windowSamples = 1600}) {
    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount == 0) return 0.0;
    if (sampleCount < windowSamples) return computeRms(pcmBytes);

    final byteData = ByteData.sublistView(pcmBytes);
    double maxWindowRms = 0.0;
    final step = windowSamples ~/ 2;

    for (int start = 0; start <= sampleCount - windowSamples; start += step) {
      double sumSquares = 0.0;
      for (int i = 0; i < windowSamples; i++) {
        final sample = byteData.getInt16((start + i) * 2, Endian.little) / 32768.0;
        sumSquares += sample * sample;
      }
      final winRms = math.sqrt(sumSquares / windowSamples);
      if (winRms > maxWindowRms) {
        maxWindowRms = winRms;
      }
    }
    return maxWindowRms;
  }

  /// Safely boosts quiet speech into Whisper's nominal dynamic range.
  /// If the peak amplitude is between [minPeakForBoost] and [nominalPeak], applies linear gain up to [maxGain].
  static Float32List optimizeDynamicRange(
    Float32List samples, {
    double nominalPeak = 0.70,
    double minPeakForBoost = 0.002, // ~65 in 16-bit
    double maxGain = 8.0,
  }) {
    if (samples.isEmpty) return samples;

    double maxVal = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final absVal = samples[i].abs();
      if (absVal > maxVal) {
        maxVal = absVal;
      }
    }

    // If signal is too quiet to be speech (ambient noise) or already sufficiently loud, preserve it
    if (maxVal < minPeakForBoost || maxVal >= nominalPeak) {
      return samples;
    }

    final double calculatedGain = math.min(maxGain, nominalPeak / maxVal);
    final boosted = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      boosted[i] = (samples[i] * calculatedGain).clamp(-1.0, 1.0);
    }
    return boosted;
  }

  /// Computes minimum and maximum values in a float sample buffer [-1.0, 1.0].
  static (double min, double max) computeFloatMinMax(Float32List samples) {
    if (samples.isEmpty) return (0.0, 0.0);
    double minVal = samples[0];
    double maxVal = samples[0];
    for (int i = 1; i < samples.length; i++) {
      final s = samples[i];
      if (s < minVal) minVal = s;
      if (s > maxVal) maxVal = s;
    }
    return (minVal, maxVal);
  }

  /// Computes the Root Mean Square (RMS) energy directly from 32-bit float samples [-1.0, 1.0].
  static double computeFloatRms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sumSquares += samples[i] * samples[i];
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Calculates audio duration in milliseconds from sample count and sample rate.
  static Duration calculateDuration(int sampleCount, {int sampleRate = 16000}) {
    if (sampleRate <= 0 || sampleCount <= 0) return Duration.zero;
    final ms = (sampleCount * 1000) ~/ sampleRate;
    return Duration(milliseconds: ms);
  }

  /// Packages raw signed 16-bit little-endian PCM bytes into standard WAV format with 44-byte RIFF header.
  static Uint8List pcm16ToWav(Uint8List pcmBytes, {int sampleRate = 16000, int numChannels = 1}) {
    final byteRate = sampleRate * numChannels * 2;
    final blockAlign = numChannels * 2;
    final subChunk2Size = pcmBytes.length;
    final chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);
    // 'RIFF' chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    // 'fmt ' subchunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)
    // 'data' subchunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, subChunk2Size, Endian.little);

    final builder = BytesBuilder(copy: false);
    builder.add(header.buffer.asUint8List());
    builder.add(pcmBytes);
    return builder.takeBytes();
  }
}

