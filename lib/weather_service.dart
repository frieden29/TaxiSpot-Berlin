import 'dart:convert';
import 'package:http/http.dart' as http;

class BerlinWeather {
  final double temperature;
  final double precipitation;
  final int weatherCode;
  final DateTime berlinTime;

  const BerlinWeather({
    required this.temperature,
    required this.precipitation,
    required this.weatherCode,
    required this.berlinTime,
  });

  bool get isRainy =>
      precipitation > 0 ||
      (weatherCode >= 51 && weatherCode <= 67) ||
      (weatherCode >= 80 && weatherCode <= 82) ||
      (weatherCode >= 95 && weatherCode <= 99);
}

class WeatherService {
  static Future<BerlinWeather> getWeather() async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '52.52',
        'longitude': '13.405',
        'current':
            'temperature_2m,precipitation,weather_code',
        'timezone': 'Europe/Berlin',
      },
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception('Weather API error');
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final current =
        data['current'] as Map<String, dynamic>;

    return BerlinWeather(
      temperature:
          (current['temperature_2m'] as num).toDouble(),
      precipitation:
          (current['precipitation'] as num).toDouble(),
      weatherCode:
          (current['weather_code'] as num).toInt(),
      berlinTime:
          DateTime.parse(current['time'] as String),
    );
  }
}