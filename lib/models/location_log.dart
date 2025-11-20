class LocationLog {
  final String? id;  // UUID
  final String workSessionId;  // UUID
  final int locationId;
  final String userId;  // UUID
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final int? duration;  // Backend: duration (seconds)
  final double? checkinLat;
  final double? checkinLng;
  final String? checkInNotes;
  final String? checkOutNotes;
  final String status; // 'checked_in', 'checked_out'

  LocationLog({
    this.id,
    required this.workSessionId,
    required this.locationId,
    required this.userId,
    required this.checkedInAt,
    this.checkedOutAt,
    this.duration,
    this.checkinLat,
    this.checkinLng,
    this.checkInNotes,
    this.checkOutNotes,
    required this.status,
  });

  factory LocationLog.fromJson(Map<String, dynamic> json) {
    return LocationLog(
      id: json['id']?.toString(),
      workSessionId: json['work_session_id']?.toString() ?? '',
      locationId: json['location_id'] ?? 0,
      userId: json['user_id']?.toString() ?? '',
      checkedInAt: DateTime.parse(json['checked_in_at']),
      checkedOutAt: json['checked_out_at'] != null 
          ? DateTime.parse(json['checked_out_at']) 
          : null,
      duration: json['duration'],
      checkinLat: json['check_in_coordinates']?['latitude']?.toDouble(),
      checkinLng: json['check_in_coordinates']?['longitude']?.toDouble(),
      checkInNotes: json['check_in_notes'],
      checkOutNotes: json['check_out_notes'],
      status: json['status'] ?? 'checked_in',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'work_session_id': workSessionId,
      'location_id': locationId,
      'user_id': userId,
      'checked_in_at': checkedInAt.toIso8601String(),
      'checked_out_at': checkedOutAt?.toIso8601String(),
      'duration': duration,
      'check_in_coordinates': {
        'latitude': checkinLat,
        'longitude': checkinLng,
      },
      'check_in_notes': checkInNotes,
      'check_out_notes': checkOutNotes,
      'status': status,
    };
  }

  bool get isInProgress => status == 'checked_in';
  bool get isCompleted => status == 'checked_out';
  bool get isSkipped => status == 'skipped';
  bool get isPendingCheckIn => status == 'pending_check_in';
  bool get isPendingCheckOut => status == 'pending_check_out';
  
  // notes getter (iki notu birleştir)
  String? get notes {
    if (checkOutNotes != null && checkOutNotes!.isNotEmpty) {
      return checkOutNotes;
    }
    return checkInNotes;
  }
}

