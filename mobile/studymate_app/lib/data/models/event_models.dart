/// Modèles de la gestion « Événements & Notifications ».
library;

DateTime _parseDate(Object? value) => DateTime.parse(value as String).toLocal();

DateTime? _parseOptionalDate(Object? value) =>
    value == null ? null : _parseDate(value);

const eventTypeLabels = <String, String>{
  'exam': 'Examen',
  'deadline': 'Échéance',
  'class': 'Cours',
  'study': 'Révision',
  'personal': 'Personnel',
  'other': 'Autre',
};

const eventStatusLabels = <String, String>{
  'planned': 'Prévu',
  'done': 'Terminé',
  'cancelled': 'Annulé',
};

/// Décalages de rappel proposés (minutes avant le début).
const reminderChoices = <int, String>{
  0: 'À l’heure',
  5: '5 min',
  15: '15 min',
  30: '30 min',
  60: '1 h',
  120: '2 h',
  1440: '1 jour',
  2880: '2 jours',
};

class StudyEvent {
  const StudyEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.startsAt,
    this.endsAt,
    this.description,
    this.courseId,
    this.location,
    this.latitude,
    this.longitude,
    this.status = 'planned',
    this.reminderOffsets = const [],
  });

  final String id;
  final String title;
  final String eventType;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? description;
  final String? courseId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String status;
  final List<int> reminderOffsets;

  factory StudyEvent.fromJson(Map<String, dynamic> json) => StudyEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        eventType: json['event_type'] as String,
        startsAt: _parseDate(json['starts_at']),
        endsAt: _parseOptionalDate(json['ends_at']),
        description: json['description'] as String?,
        courseId: json['course_id'] as String?,
        location: json['location'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        status: (json['status'] as String?) ?? 'planned',
        reminderOffsets: ((json['reminder_offsets'] as List<dynamic>?) ?? [])
            .map((value) => value as int)
            .toList(),
      );

  /// Corps JSON pour la création / la modification.
  Map<String, dynamic> toPayload() => {
        'title': title,
        'event_type': eventType,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'description': description,
        'course_id': courseId,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'reminder_offsets': reminderOffsets,
      };

  String get typeLabel => eventTypeLabels[eventType] ?? 'Autre';
  String get statusLabel => eventStatusLabels[status] ?? status;
}

/// Entrée du calendrier unifié : événement, occurrence de cours ou tâche.
class CalendarItem {
  const CalendarItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.startsAt,
    required this.category,
    this.endsAt,
    this.status,
    this.location,
    this.completed,
  });

  final String kind; // event | course | task
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String category;
  final String? status;
  final String? location;
  final bool? completed;

  factory CalendarItem.fromJson(Map<String, dynamic> json) => CalendarItem(
        kind: json['kind'] as String,
        id: json['id'] as String,
        title: json['title'] as String,
        startsAt: _parseDate(json['starts_at']),
        endsAt: _parseOptionalDate(json['ends_at']),
        category: json['category'] as String,
        status: json['status'] as String?,
        location: json['location'] as String?,
        completed: json['completed'] as bool?,
      );

  bool get isEvent => kind == 'event';
  bool get isCancelled => status == 'cancelled';
  bool get isDone => status == 'done' || completed == true;
  String get kindLabel => switch (kind) {
        'course' => 'Cours',
        'task' => 'Tâche',
        _ => eventTypeLabels[category] ?? 'Événement',
      };
}

class EventConflictInfo {
  const EventConflictInfo({
    required this.kind,
    required this.title,
    required this.startsAt,
    required this.endsAt,
  });

  final String kind;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  factory EventConflictInfo.fromJson(Map<String, dynamic> json) =>
      EventConflictInfo(
        kind: json['kind'] as String,
        title: json['title'] as String,
        startsAt: _parseDate(json['starts_at']),
        endsAt: _parseDate(json['ends_at']),
      );
}

/// Brouillon renvoyé par l'IA : il pré-remplit le formulaire, rien n'est enregistré.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.eventType,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.description,
  });

  final String title;
  final String eventType;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? description;

  factory EventDraft.fromJson(Map<String, dynamic> json) => EventDraft(
        title: json['title'] as String,
        eventType: json['event_type'] as String,
        startsAt: _parseDate(json['starts_at']),
        endsAt: _parseOptionalDate(json['ends_at']),
        location: json['location'] as String?,
        description: json['description'] as String?,
      );
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String name;
  final String? address;

  /// Fournies directement par OpenStreetMap (Photon/Geoapify) ; absentes avec
  /// Google, qui demande un appel de détails.
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        placeId: json['place_id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class PlaceDetails {
  const PlaceDetails({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) => PlaceDetails(
        name: json['name'] as String,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.payload = const {},
    this.readAt,
  });

  final String id;
  final String type; // reminder | deadline | exam | system
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  String? get eventId => payload['event_id'] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['notification_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: _parseDate(json['created_at']),
        payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
        readAt: _parseOptionalDate(json['read_at']),
      );

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        payload: payload,
        readAt: readAt ?? this.readAt,
      );
}
