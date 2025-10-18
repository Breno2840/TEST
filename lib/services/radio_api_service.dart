import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/radio_station.dart';

class RadioApiService {
  final _baseUrl = 'https://radioapp-b4746-default-rtdb.firebaseio.com/.json';

  Future<List<RadioStation>> fetchStations() async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {'User-Agent': 'RadioApp/1.0', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        List<RadioStation> loadedStations = [];

        if (data is List) {
          loadedStations = data
              .where((station) => station['ativo'] == true)
              .map((json) => RadioStation.fromJson(json))
              .where((station) => station.streamUrl.isNotEmpty)
              .toList();
        } else if (data is Map) {
          for (var key in data.keys) {
            if (data[key] is List) {
              loadedStations = (data[key] as List)
                  .where((station) => station['ativo'] == true)
                  .map((json) => RadioStation.fromJson(json))
                  .where((station) => station.streamUrl.isNotEmpty)
                  .toList();
              break;
            }
          }
        }
        return loadedStations;
      } else {
        throw Exception('Falha ao carregar estações: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Erro no serviço da API: $e');
      throw Exception('Não foi possível conectar ao servidor.');
    }
  }
}
