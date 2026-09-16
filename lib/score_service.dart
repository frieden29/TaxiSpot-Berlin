import 'weather_service.dart';

class ScoreService {
  static int calculate({
    required String spotName,
    required int hour,
    required int weekday,
    required BerlinWeather? weather,
  }) {
    int score = 50;

    // Berlin Hauptbahnhof
    if (spotName == 'Berlin Hauptbahnhof') {
      score = 65;

      if (hour >= 6 && hour <= 10) {
        score += 20;
      }

      if (hour >= 16 && hour <= 21) {
        score += 15;
      }
    }

    // BER Airport
    if (spotName == 'BER Airport') {
      score = 60;

      if (hour >= 5 && hour <= 9) {
        score += 20;
      }

      if (hour >= 17 && hour <= 23) {
        score += 20;
      }
    }

    // Alexanderplatz
    if (spotName == 'Alexanderplatz') {
      score = 55;

      if (hour >= 18 && hour <= 23) {
        score += 25;
      }
    }

    // Zoologischer Garten
    if (spotName == 'Zoologischer Garten') {
      score = 55;

      if (hour >= 10 && hour <= 20) {
        score += 15;
      }
    }

    // Potsdamer Platz
    if (spotName == 'Potsdamer Platz') {
      score = 55;

      if (hour >= 18 && hour <= 23) {
        score += 20;
      }
    }

    // Weekend adjustment
    if (weekday == DateTime.saturday ||
        weekday == DateTime.sunday) {
      if (spotName == 'Alexanderplatz' ||
          spotName == 'Potsdamer Platz') {
        score += 5;
      }
    }

    // Weather adjustment
    if (weather != null && weather.isRainy) {
      score += 10;
    }

    return score.clamp(0, 100).toInt();
  }
}