import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/services/asr/pcm_converter.dart';

void main() {
  group('PCMConverter Tests', () {
    test('pcm16ToFloat32 accurately normalizes signed 16-bit PCM bytes', () {
      final byteData = ByteData(8);
      // Sample 0: 0 -> 0.0
      byteData.setInt16(0, 0, Endian.little);
      // Sample 1: 32767 -> ~0.999969
      byteData.setInt16(2, 32767, Endian.little);
      // Sample 2: -32768 -> -1.0
      byteData.setInt16(4, -32768, Endian.little);
      // Sample 3: 16384 -> 0.5
      byteData.setInt16(6, 16384, Endian.little);

      final pcmBytes = byteData.buffer.asUint8List();
      final floats = PCMConverter.pcm16ToFloat32(pcmBytes);

      expect(floats.length, 4);
      expect(floats[0], closeTo(0.0, 0.0001));
      expect(floats[1], closeTo(1.0, 0.0001));
      expect(floats[2], closeTo(-1.0, 0.0001));
      expect(floats[3], closeTo(0.5, 0.0001));
    });

    test('pcm16ToFloat32 handles empty and odd-length buffers safely', () {
      final emptyFloats = PCMConverter.pcm16ToFloat32(Uint8List(0));
      expect(emptyFloats.length, 0);

      // 5 bytes = 2 full 16-bit samples, 1 trailing byte dropped safely
      final oddBytes = Uint8List.fromList([0, 0, 0, 0, 255]);
      final oddFloats = PCMConverter.pcm16ToFloat32(oddBytes);
      expect(oddFloats.length, 2);
    });

    test('float32ToPcm16 roundtrips normalized values back to PCM', () {
      final floats = Float32List.fromList([-1.0, -0.5, 0.0, 0.5, 1.0]);
      final pcmBytes = PCMConverter.float32ToPcm16(floats);

      expect(pcmBytes.length, 10);
      final byteData = ByteData.sublistView(pcmBytes);

      expect(byteData.getInt16(0, Endian.little), -32767);
      expect(byteData.getInt16(2, Endian.little), closeTo(-16384, 2));
      expect(byteData.getInt16(4, Endian.little), 0);
      expect(byteData.getInt16(6, Endian.little), closeTo(16384, 2));
      expect(byteData.getInt16(8, Endian.little), 32767);
    });

    test('computeRms returns 0.0 for silence and high energy for peak signal', () {
      final silence = Uint8List(320); // 160 zero samples
      expect(PCMConverter.computeRms(silence), 0.0);

      // Create max square wave
      final peakData = ByteData(320);
      for (int i = 0; i < 160; i++) {
        peakData.setInt16(i * 2, i.isEven ? 32767 : -32768, Endian.little);
      }
      final peakRms = PCMConverter.computeRms(peakData.buffer.asUint8List());
      expect(peakRms, closeTo(1.0, 0.01));
    });

    test('calculateDuration accurately computes milliseconds', () {
      // 16000 samples @ 16kHz = 1000 ms
      expect(
        PCMConverter.calculateDuration(16000, sampleRate: 16000),
        const Duration(milliseconds: 1000),
      );

      // 3200 samples @ 16kHz = 200 ms
      expect(
        PCMConverter.calculateDuration(3200, sampleRate: 16000),
        const Duration(milliseconds: 200),
      );
    });

    test('computePeakAmplitude and countNonZeroBytes correctly measure signal metrics', () {
      final silence = Uint8List(320);
      expect(PCMConverter.computePeakAmplitude(silence), 0);
      expect(PCMConverter.countNonZeroBytes(silence), 0);

      final byteData = ByteData(8);
      byteData.setInt16(0, 1500, Endian.little);
      byteData.setInt16(2, -3200, Endian.little);
      byteData.setInt16(4, 50, Endian.little);
      byteData.setInt16(6, 0, Endian.little);
      final pcm = byteData.buffer.asUint8List();

      expect(PCMConverter.computePeakAmplitude(pcm), 3200);
      expect(PCMConverter.countNonZeroBytes(pcm), greaterThan(0));
    });

    test('computeMaxWindowRms detects short vocal burst amidst silence', () {
      // 32000 bytes = 16000 samples = 1 second
      final buffer = ByteData(32000);
      // Insert a 100ms burst (1600 samples) of square wave amplitude 16384 (0.5) at sample 8000
      for (int i = 8000; i < 9600; i++) {
        buffer.setInt16(i * 2, i.isEven ? 16384 : -16384, Endian.little);
      }
      final pcm = buffer.buffer.asUint8List();

      final overallRms = PCMConverter.computeRms(pcm);
      final windowRms = PCMConverter.computeMaxWindowRms(pcm, windowSamples: 1600);

      expect(overallRms, closeTo(0.158, 0.02));
      expect(windowRms, closeTo(0.5, 0.02));
      expect(windowRms, greaterThan(overallRms * 2.5));
    });

    test('optimizeDynamicRange boosts quiet speech while preserving nominal audio', () {
      // Quiet signal: peak is 0.1
      final quiet = Float32List.fromList([-0.05, 0.0, 0.1, -0.08]);
      final boosted = PCMConverter.optimizeDynamicRange(quiet, nominalPeak: 0.70);
      expect(boosted[2], closeTo(0.70, 0.01));

      // Normal signal: peak is 0.8
      final normal = Float32List.fromList([-0.5, 0.8, -0.3]);
      final unchanged = PCMConverter.optimizeDynamicRange(normal, nominalPeak: 0.70);
      expect(unchanged[1], closeTo(0.8, 0.0001));
    });
  });
}

