import 'package:flutter/material.dart';

/// docs/02_CARD_CATALOG.md §Icons — the backend sends a stable `icon` string; the app maps it
/// to a Material glyph. `condition_code` is the WMO code and maps to the same icon set.
class AppIcons {
  AppIcons._();

  static const Map<String, IconData> _byName = <String, IconData>{
    'sun': Icons.wb_sunny_outlined,
    'moon': Icons.nightlight_outlined,
    'cloud': Icons.cloud_outlined,
    'partly_cloudy': Icons.wb_cloudy_outlined,
    'rain': Icons.grain,
    'heavy_rain': Icons.water_drop_outlined,
    'thunderstorm': Icons.thunderstorm_outlined,
    'fog': Icons.foggy,
    'haze': Icons.blur_on,
    'wind': Icons.air,
    'snow': Icons.ac_unit,
    'hail': Icons.grain,
    'dust': Icons.blur_circular,
    'cyclone': Icons.cyclone,
    'aqi': Icons.masks_outlined,
    'mask': Icons.masks_outlined,
    'uv': Icons.wb_sunny_outlined,
    'humidity': Icons.water_drop_outlined,
    'pollen': Icons.local_florist_outlined,
    'run': Icons.directions_run,
    'sunrise': Icons.wb_twilight,
    'sunset': Icons.wb_twilight,
    'heat': Icons.thermostat,
    'wave': Icons.waves,
    'tide': Icons.waves,
    'water': Icons.pool,
    'plane': Icons.flight_takeoff,
    'suitcase': Icons.luggage_outlined,
    'school': Icons.school_outlined,
    'umbrella': Icons.umbrella_outlined,
    'soil': Icons.landscape_outlined,
    'sprout': Icons.eco_outlined,
    'frost': Icons.ac_unit,
    'traffic': Icons.traffic_outlined,
    'eye': Icons.visibility_outlined,
    'storm': Icons.thunderstorm_outlined,
    'calendar': Icons.calendar_month_outlined,
    'comfort': Icons.spa_outlined,
    'warning': Icons.warning_amber_rounded,
    'radar': Icons.radar,
    'pin': Icons.push_pin_outlined,
  };

  static IconData byName(String? name, {IconData fallback = Icons.cloud_outlined}) =>
      _byName[name] ?? fallback;

  /// WMO weather code (+ day/night) → icon name from the docs/02 set.
  static String conditionIconName(int? code, {bool isDay = true}) {
    switch (code) {
      case 0:
        return isDay ? 'sun' : 'moon';
      case 1:
      case 2:
        return 'partly_cloudy';
      case 3:
        return 'cloud';
      case 45:
      case 48:
        return 'fog';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
      case 61:
      case 80:
        return 'rain';
      case 63:
      case 65:
      case 66:
      case 67:
      case 81:
      case 82:
        return 'heavy_rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'snow';
      case 95:
      case 96:
      case 99:
        return 'thunderstorm';
      default:
        return isDay ? 'partly_cloudy' : 'moon';
    }
  }

  static IconData condition(int? code, {bool isDay = true}) =>
      byName(conditionIconName(code, isDay: isDay));

  /// Hazard string from `Warning.hazard` (docs/04 §Objects) → icon.
  static IconData hazard(String? hazard) {
    switch (hazard) {
      case 'heavy_rain':
      case 'very_heavy_rain':
      case 'flood':
        return Icons.water_drop_outlined;
      case 'thunderstorm':
      case 'lightning':
      case 'squall':
        return Icons.thunderstorm_outlined;
      case 'hail':
        return Icons.grain;
      case 'heatwave':
        return Icons.thermostat;
      case 'cold_wave':
      case 'snow':
        return Icons.ac_unit;
      case 'fog':
        return Icons.foggy;
      case 'dust_storm':
        return Icons.blur_circular;
      case 'cyclone':
        return Icons.cyclone;
      case 'strong_wind':
        return Icons.air;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  /// docs/00 personas → tile icon (onboarding + persona chips).
  static IconData persona(String id) {
    switch (id) {
      case 'health':
        return Icons.favorite_outline;
      case 'fitness':
        return Icons.directions_run;
      case 'beach':
        return Icons.beach_access_outlined;
      case 'traveler':
        return Icons.luggage_outlined;
      case 'parent':
        return Icons.family_restroom_outlined;
      case 'agriculture':
        return Icons.agriculture_outlined;
      case 'commuter':
        return Icons.directions_bus_outlined;
      case 'event_planner':
        return Icons.event_outlined;
      default:
        return Icons.person_outline;
    }
  }
}
