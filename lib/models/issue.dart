class Issue {
  final int? id;
  final int locationId;
  final int? userId;
  final String title;
  final String? description;
  final String status; // open, in_progress, resolved, closed
  final String priority; // low, medium, high, critical
  final List<String> imagePaths;
  final String reportedBy;
  final String reportedAt;
  final String? resolvedAt;
  final String? adminNotes;
  final String? resolvedBy;
  final String? address; // Location address

  Issue({
    this.id,
    required this.locationId,
    this.userId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.imagePaths,
    required this.reportedBy,
    required this.reportedAt,
    this.resolvedAt,
    this.adminNotes,
    this.resolvedBy,
    this.address,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: _safeInt(json['id']),
      locationId: _safeInt(json['location_id']) ?? 0,
      userId: _safeInt(json['user_id']),
      title: json['description']?.toString() ?? json['title']?.toString() ?? '', // Backend'de 'description' var
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'open',
      priority: json['severity']?.toString() ?? json['priority']?.toString() ?? 'medium', // Backend 'severity' kullanıyor
      imagePaths: _parseImagePaths(json['photos'] ?? json['image_paths'] ?? json['image_urls']),
      reportedBy: json['user_name']?.toString() ?? json['reported_by']?.toString() ?? json['user']?['username']?.toString() ?? '',
      reportedAt: json['created_at']?.toString() ?? json['reported_at']?.toString() ?? '',
      resolvedAt: json['resolved_at']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      resolvedBy: json['resolved_by']?.toString(),
      address: _parseAddress(json),
    );
  }

  // Helper method to parse address from location object or direct address field
  static String? _parseAddress(Map<String, dynamic> json) {
    // 1. Try location_address (new backend format)
    if (json['location_address'] != null && json['location_address'].toString().isNotEmpty) {
      return json['location_address'].toString();
    }
    
    // 2. Try direct address field (legacy format)
    if (json['address'] != null && json['address'].toString().isNotEmpty) {
      return json['address'].toString();
    }
    
    // 3. Try formatted_address at root level
    if (json['formatted_address'] != null && json['formatted_address'].toString().isNotEmpty) {
      return json['formatted_address'].toString();
    }
    
    // 4. Try location object
    if (json['location'] != null) {
      final location = json['location'];
      if (location is Map<String, dynamic>) {
        // 4a. Try formatted_address in location object
        if (location['formatted_address'] != null && location['formatted_address'].toString().isNotEmpty) {
          return location['formatted_address'].toString();
        }
        
        // 4b. Build address from location parts
        List<String> addressParts = [];
        if (location['street'] != null && location['street'].toString().isNotEmpty) {
          addressParts.add(location['street'].toString());
        }
        if (location['city'] != null && location['city'].toString().isNotEmpty) {
          addressParts.add(location['city'].toString());
        }
        if (location['zip'] != null && location['zip'].toString().isNotEmpty) {
          addressParts.add(location['zip'].toString());
        }
        if (location['state'] != null && location['state'].toString().isNotEmpty) {
          addressParts.add(location['state'].toString());
        }
        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
    }
    
    return null;
  }

  // Helper method to safely parse int values
  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  // Helper method to parse image paths (can be String or List)
  static List<String> _parseImagePaths(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      if (value.isEmpty) return [];
      // If it's a comma-separated string
      if (value.contains(',')) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [value];
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location_id': locationId,
      'user_id': userId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'image_paths': imagePaths,
      'reported_by': reportedBy,
      'reported_at': reportedAt,
      'resolved_at': resolvedAt,
      'admin_notes': adminNotes,
      'resolved_by': resolvedBy,
      'address': address,
    };
  }

  // Status getters
  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  // Priority getters
  bool get isLow => priority == 'low';
  bool get isMedium => priority == 'medium';
  bool get isHigh => priority == 'high';
  bool get isCritical => priority == 'critical';

  // Status color
  String get statusColor {
    switch (status) {
      case 'open':
        return '#FF9800'; // Orange
      case 'in_progress':
        return '#2196F3'; // Blue
      case 'resolved':
        return '#4CAF50'; // Green
      case 'closed':
        return '#9E9E9E'; // Grey
      default:
        return '#9E9E9E';
    }
  }

  // Priority color
  String get priorityColor {
    switch (priority) {
      case 'low':
        return '#4CAF50'; // Green
      case 'medium':
        return '#FF9800'; // Orange
      case 'high':
        return '#FF5722'; // Red
      case 'critical':
        return '#F44336'; // Dark Red
      default:
        return '#9E9E9E';
    }
  }

  // Status text
  String get statusText {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'in_progress':
        return 'İnceleniyor';
      case 'resolved':
        return 'Çözüldü';
      case 'closed':
        return 'Kapatıldı';
      default:
        return 'Bilinmiyor';
    }
  }

  // Priority text
  String get priorityText {
    switch (priority) {
      case 'low':
        return 'Düşük';
      case 'medium':
        return 'Orta';
      case 'high':
        return 'Yüksek';
      case 'critical':
        return 'Kritik';
      default:
        return 'Orta';
    }
  }
}
