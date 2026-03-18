enum ThreatLevel { none, uncomfortable, following, immediate }

extension ThreatLevelX on ThreatLevel {
  String get key {
    switch (this) {
      case ThreatLevel.none:
        return 'none';
      case ThreatLevel.uncomfortable:
        return 'uncomfortable';
      case ThreatLevel.following:
        return 'following';
      case ThreatLevel.immediate:
        return 'immediate';
    }
  }

  String get label {
    switch (this) {
      case ThreatLevel.none:
        return 'Safe';
      case ThreatLevel.uncomfortable:
        return 'Uncomfortable';
      case ThreatLevel.following:
        return 'Being Followed';
      case ThreatLevel.immediate:
        return 'Immediate Danger';
    }
  }
}

/// Top-level parser — Dart extensions cannot have static members.
ThreatLevel threatLevelFromKey(String s) {
  switch (s) {
    case 'uncomfortable':
      return ThreatLevel.uncomfortable;
    case 'following':
      return ThreatLevel.following;
    case 'immediate':
      return ThreatLevel.immediate;
    default:
      return ThreatLevel.none;
  }
}

class SafetyIncident {
  final int? id;
  final int startedAt;
  final int? resolvedAt;
  final ThreatLevel threatLevel;
  final double? lat;
  final double? lng;
  final String? address;
  final String? recordingPath;
  final bool isResolved;

  const SafetyIncident({
    this.id,
    required this.startedAt,
    this.resolvedAt,
    required this.threatLevel,
    this.lat,
    this.lng,
    this.address,
    this.recordingPath,
    this.isResolved = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'started_at': startedAt,
        'resolved_at': resolvedAt,
        'threat_level': threatLevel.key,
        'lat': lat,
        'lng': lng,
        'address': address,
        'recording_path': recordingPath,
        'is_resolved': isResolved ? 1 : 0,
      };

  factory SafetyIncident.fromMap(Map<String, dynamic> map) => SafetyIncident(
        id: map['id'] as int?,
        startedAt: map['started_at'] as int,
        resolvedAt: map['resolved_at'] as int?,
        threatLevel: threatLevelFromKey(map['threat_level'] as String? ?? ''),
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        address: map['address'] as String?,
        recordingPath: map['recording_path'] as String?,
        isResolved: (map['is_resolved'] as int? ?? 0) == 1,
      );

  SafetyIncident copyWith({
    ThreatLevel? threatLevel,
    String? recordingPath,
    int? resolvedAt,
    bool? isResolved,
  }) =>
      SafetyIncident(
        id: id,
        startedAt: startedAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        threatLevel: threatLevel ?? this.threatLevel,
        lat: lat,
        lng: lng,
        address: address,
        recordingPath: recordingPath ?? this.recordingPath,
        isResolved: isResolved ?? this.isResolved,
      );
}
