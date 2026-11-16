import 'package:flutter_test/flutter_test.dart';
import 'package:matladu_ai/data/models/connection_mode_model.dart';
import 'package:matladu_ai/data/services/engine/engine_selection_manager.dart';
import 'package:matladu_ai/data/services/network_connectivity_service.dart';

void main() {
  group('Engine Selection Manager Tests — Phase 8 Architecture', () {
    test('On-Device mode strictly enforces local processing regardless of network', () async {
      final connectivity = NetworkConnectivityService();
      final manager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.onDevice,
        autoSwitchEnabled: false,
      );

      final resolution = await manager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      expect(resolution.isFullyOffline, isTrue);
      expect(resolution.isOnlineRequired, isFalse);
      expect(resolution.asrEngine, equals(EngineType.onDevice));
      expect(resolution.translationEngine, equals(EngineType.onDevice));
      expect(resolution.statusTitle, equals('Offline - Ready'));
    });

    test('Online mode performs cloud translation with on-device ASR and TTS', () async {
      final connectivity = NetworkConnectivityService();
      connectivity.updateStateForTesting(const NetworkState(
        isConnected: true,
        isValidated: true,
        isWifi: true,
        isCellular: false,
        type: 'wifi',
      ));
      final manager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.cloudAi,
        autoSwitchEnabled: false,
      );

      final resolution = await manager.resolve(
        sourceLanguageCode: 'en',
        targetLanguageCode: 'te',
      );

      // Phase 8: Speech recognition runs on-device, translation uses external API
      expect(resolution.asrEngine, equals(EngineType.onDevice));
      expect(resolution.translationEngine, equals(EngineType.onlineCloud));
      expect(resolution.ttsEngine, equals(EngineType.onDevice));
      expect(resolution.statusTitle, equals('Online - Cloud Translation'));
      expect(resolution.statusDescription, contains('Zero audio upload'));
    });

    test('Automatic mode dynamically switches between Online and Offline', () async {
      final connectivity = NetworkConnectivityService();
      connectivity.updateStateForTesting(const NetworkState(
        isConnected: true,
        isValidated: true,
        isWifi: true,
        isCellular: false,
        type: 'wifi',
      ));
      final manager = EngineSelectionManager(
        connectivityService: connectivity,
        initialMode: ConnectionModeType.automatic,
      );

      // Connected state
      var res = await manager.resolve(sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.asrEngine, equals(EngineType.onDevice));
      expect(res.translationEngine, equals(EngineType.onlineCloud));
      expect(res.statusTitle, equals('Auto - Online Translation'));

      // Disconnected state
      connectivity.updateStateForTesting(const NetworkState(
        isConnected: false,
        isValidated: false,
        isWifi: false,
        isCellular: false,
        type: 'none',
      ));
      res = await manager.resolve(sourceLanguageCode: 'en', targetLanguageCode: 'te');
      expect(res.asrEngine, equals(EngineType.onDevice));
      expect(res.translationEngine, equals(EngineType.onDevice));
      expect(res.statusTitle, equals('Auto - Offline Translation'));
    });
  });
}
