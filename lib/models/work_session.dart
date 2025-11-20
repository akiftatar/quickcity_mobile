class WorkSession {
  final String? id;  // UUID
  final String userId;  // UUID
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? totalDuration;  // Backend: total_duration (seconds)
  final int totalAssignedLocations;
  final int completedLocations;
  final double completionRate;
  final String? notes;
  final String status; // 'active', 'completed', 'cancelled'

  WorkSession({
    this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.totalDuration,
    required this.totalAssignedLocations,
    this.completedLocations = 0,
    this.completionRate = 0.0,
    this.notes,
    required this.status,
  });

  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      totalDuration: json['total_duration'],
      totalAssignedLocations: json['location_logs_count'] ?? 0,
      completedLocations: json['completed_logs_count'] ?? 0,
      completionRate: 0.0,  // Backend'de yok, hesaplanacak
      notes: json['notes'],
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'total_duration': totalDuration,
      'location_logs_count': totalAssignedLocations,
      'completed_logs_count': completedLocations,
      'notes': notes,
      'status': status,
    };
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  
  int get remainingLocations => totalAssignedLocations - completedLocations;
}

