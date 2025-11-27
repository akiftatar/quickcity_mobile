class Location {
  final int id;
  final String? assignmentId; // Backend assignment ID (UUID)
  final double lat;
  final double lng;
  final String? street;
  final String? city;
  final String? state;
  final String? zip;
  final String? formattedAddress;
  final String? description;
  final String clusterLabel;
  final Customer? customer;
  final WorkAreas workAreas;
  final List<dynamic> attachments;
  final String assignedAt;
  final int? waypointIndex; // Rotalama sırası
  final bool isRouted; // Rotalanmış mı?

  Location({
    required this.id,
    this.assignmentId,
    required this.lat,
    required this.lng,
    this.street,
    this.city,
    this.state,
    this.zip,
    this.formattedAddress,
    this.description,
    required this.clusterLabel,
    this.customer,
    required this.workAreas,
    required this.attachments,
    required this.assignedAt,
    this.waypointIndex,
    this.isRouted = false,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    // Nested map'leri güvenli şekilde dönüştür
    final customerData = json['customer'];
    final workAreasData = json['work_areas'];
    
    Map<String, dynamic>? customerMap;
    if (customerData != null) {
      if (customerData is Map) {
        customerMap = Map<String, dynamic>.from(customerData);
      } else {
        customerMap = null;
      }
    }
    
    Map<String, dynamic> workAreasMap = {};
    if (workAreasData != null && workAreasData is Map) {
      workAreasMap = Map<String, dynamic>.from(workAreasData);
    }
    
    return Location(
      id: _safeInt(json['id']),
      assignmentId: json['assignment_id']?.toString() ?? json['assignmentId']?.toString(),
      lat: _safeDouble(json['lat']),
      lng: _safeDouble(json['lng']),
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      zip: json['zip']?.toString(),
      formattedAddress: json['formatted_address']?.toString(),
      description: json['description']?.toString(),
      clusterLabel: json['cluster_label']?.toString() ?? '',
      customer: customerMap != null ? Customer.fromJson(customerMap) : null,
      workAreas: WorkAreas.fromJson(workAreasMap),
      attachments: _parseAttachments(json['attachments']),
      assignedAt: json['assigned_at']?.toString() ?? '',
      waypointIndex: json['waypoint_index'] != null ? _safeInt(json['waypoint_index']) : null,
      isRouted: json['is_routed'] == true || json['is_routed'] == 1,
    );
  }

  // Güvenli int parsing
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Güvenli double parsing
  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'lat': lat,
      'lng': lng,
      'street': street,
      'city': city,
      'state': state,
      'zip': zip,
      'formatted_address': formattedAddress,
      'description': description,
      'cluster_label': clusterLabel,
      'customer': customer?.toJson(),
      'work_areas': workAreas.toJson(),
      'attachments': attachments,
      'assigned_at': assignedAt,
      'waypoint_index': waypointIndex,
      'is_routed': isRouted,
    };
  }

  String get displayAddress {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }
    
    List<String> addressParts = [];
    if (street != null && street!.isNotEmpty) addressParts.add(street!);
    if (city != null && city!.isNotEmpty) addressParts.add(city!);
    if (zip != null && zip!.isNotEmpty) addressParts.add(zip!);
    
    return addressParts.isNotEmpty ? addressParts.join(', ') : 'Adres bilgisi yok';
  }
  
  // PERFORMANS: Cache'lenmiş alan hesabı
  double? _cachedRelevantArea;
  
  // Cluster'a göre ilgili alanı al
  double get relevantArea {
    _cachedRelevantArea ??= workAreas.getRelevantArea(clusterLabel);
    return _cachedRelevantArea!;
  }

  // Attachments verisini parse et - string veya list olabilir
  static List<dynamic> _parseAttachments(dynamic attachments) {
    if (attachments == null) {
      return [];
    }
    
    if (attachments is List) {
      return attachments;
    }
    
    if (attachments is String) {
      // String ise, tek elemanlı liste olarak döndür
      return [attachments];
    }
    
    // Diğer durumlar için boş liste
    return [];
  }
}

class Customer {
  final int id;
  final String name;

  Customer({
    required this.id,
    required this.name,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class WorkAreas {
  final double gehwege1;
  final double gehwege15;
  final double parkingSpacesSurface;
  final double parkingSpacesPaths;
  final double handreinigung;

  WorkAreas({
    required this.gehwege1,
    required this.gehwege15,
    required this.parkingSpacesSurface,
    required this.parkingSpacesPaths,
    required this.handreinigung,
  });

  factory WorkAreas.fromJson(Map<String, dynamic> json) {
    return WorkAreas(
      gehwege1: _safeDouble(json['gehwege_1']),
      gehwege15: _safeDouble(json['gehwege_1_5']),
      parkingSpacesSurface: _safeDouble(json['parking_spaces_surface']),
      parkingSpacesPaths: _safeDouble(json['parking_spaces_paths']),
      handreinigung: _safeDouble(json['handreinigung']),
    );
  }

  // Güvenli double parsing
  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'gehwege_1': gehwege1,
      'gehwege_1_5': gehwege15,
      'parking_spaces_surface': parkingSpacesSurface,
      'parking_spaces_paths': parkingSpacesPaths,
      'handreinigung': handreinigung,
    };
  }

  // ESKI METOD - Tüm alanları toplar (Yanlış!)
  double get totalArea => gehwege1 + gehwege15 + parkingSpacesSurface + parkingSpacesPaths + handreinigung;
  
  // Cluster tipine göre doğru alanı hesapla
  double getRelevantArea(String clusterLabel) {
    final clusterType = clusterLabel.toUpperCase();
    
    if (clusterType.startsWith('MFILE')) {
      // M-File: Sadece gehwege'ler
      return gehwege1 + gehwege15;
    } else if (clusterType.startsWith('HFILE')) {
      // H-File: Sadece handreinigung (manuel temizlik)
      return handreinigung;
    } else if (clusterType.startsWith('UFILE')) {
      // U-File: Sadece park alanları
      return parkingSpacesSurface + parkingSpacesPaths;
    } else {
      // Bilinmeyen cluster: Tümünü topla (güvenli fallback)
      return totalArea;
    }
  }
}
