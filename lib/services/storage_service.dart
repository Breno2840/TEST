import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _lastStationKey = 'lastStation';

  Future<void> saveLastStationIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastStationKey, index);
    } catch (e) {
      print('Erro ao salvar estação: $e');
    }
  }

  Future<int> loadLastStationIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastStationKey) ?? 0;
    } catch (e) {
      print('Erro ao carregar última estação: $e');
      return 0;
    }
  }
}
