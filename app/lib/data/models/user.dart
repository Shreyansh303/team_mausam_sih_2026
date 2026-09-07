import 'json.dart';
import 'location.dart';

/// docs/04_API_CONTRACT.md §Objects `User.personas[]`.
class PersonaWeight {
  const PersonaWeight({required this.id, this.weight = 1.0});

  final String id;
  final double weight;

  factory PersonaWeight.fromJson(Map<String, dynamic> json) => PersonaWeight(
        id: asString(json['id']),
        weight: asDouble(json['weight']) ?? 1.0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'weight': weight};
}

/// docs/04_API_CONTRACT.md §Objects `User.school_windows[] / commute_windows[]`.
class TimeWindow {
  const TimeWindow({required this.label, required this.start, required this.end});

  final String label;
  final String start; // "07:00"
  final String end; // "09:00"

  factory TimeWindow.fromJson(Map<String, dynamic> json) => TimeWindow(
        label: asString(json['label']),
        start: asString(json['start']),
        end: asString(json['end']),
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'label': label, 'start': start, 'end': end};
}

/// docs/04_API_CONTRACT.md §Objects `User`.
class User {
  const User({
    required this.id,
    this.phone,
    this.isGuest = true,
    this.language = 'en',
    this.units = 'metric',
    this.personas = const <PersonaWeight>[],
    this.homeLocation,
    this.schoolWindows = const <TimeWindow>[],
    this.commuteWindows = const <TimeWindow>[],
    this.createdAt,
  });

  final String id;
  final String? phone;
  final bool isGuest;
  final String language;
  final String units;
  final List<PersonaWeight> personas;
  final LocationResult? homeLocation;
  final List<TimeWindow> schoolWindows;
  final List<TimeWindow> commuteWindows;
  final String? createdAt;

  List<String> get personaIds => personas.map((p) => p.id).toList();

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: asString(json['id']),
        phone: asStringOrNull(json['phone']),
        isGuest: asBool(json['is_guest'], fallback: true),
        language: asString(json['language'], fallback: 'en'),
        units: asString(json['units'], fallback: 'metric'),
        personas: asList(json['personas'], PersonaWeight.fromJson),
        homeLocation: json['home_location'] == null
            ? null
            : LocationResult.fromJson(asMap(json['home_location'])),
        schoolWindows: asList(json['school_windows'], TimeWindow.fromJson),
        commuteWindows: asList(json['commute_windows'], TimeWindow.fromJson),
        createdAt: asStringOrNull(json['created_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'phone': phone,
        'is_guest': isGuest,
        'language': language,
        'units': units,
        'personas': personas.map((p) => p.toJson()).toList(),
        'home_location': homeLocation?.toJson(),
        'school_windows': schoolWindows.map((w) => w.toJson()).toList(),
        'commute_windows': commuteWindows.map((w) => w.toJson()).toList(),
        'created_at': createdAt,
      };
}

/// The eight personas from docs/00_VISION.md, in the order the onboarding grid shows them.
/// `labelKey`/`tagKey` resolve against the ARB strings in `lib/l10n`.
class Persona {
  const Persona(this.id);

  final String id;

  static const List<Persona> all = <Persona>[
    Persona('parent'),
    Persona('commuter'),
    Persona('health'),
    Persona('fitness'),
    Persona('traveler'),
    Persona('beach'),
    Persona('agriculture'),
    Persona('event_planner'),
  ];

  static const List<String> ids = <String>[
    'parent',
    'commuter',
    'health',
    'fitness',
    'traveler',
    'beach',
    'agriculture',
    'event_planner',
  ];
}
