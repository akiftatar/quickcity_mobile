class User {
  final String id;
  final String username;
  final String firstname;
  final String lastname;
  final String email;
  final String? emailVerifiedAt;
  final List<String> roles; // Array of role names
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  User({
    required this.id,
    required this.username,
    required this.firstname,
    required this.lastname,
    required this.email,
    this.emailVerifiedAt,
    required this.roles,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Roles array'den role name'leri çıkar
    List<String> rolesList = [];
    if (json['roles'] != null && json['roles'] is List) {
      rolesList = (json['roles'] as List)
          .map((role) => role['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    }
    
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      email: json['email'] ?? '',
      emailVerifiedAt: json['email_verified_at'],
      roles: rolesList,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      deletedAt: json['deleted_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'firstname': firstname,
      'lastname': lastname,
      'email': email,
      'email_verified_at': emailVerifiedAt,
      'roles': roles,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  String get fullName => '$firstname $lastname';
  
  // Role kontrol metodları
  bool get isSuperAdmin {
    return roles.any((role) => 
      role.toLowerCase() == 'superadmin' || 
      role.toLowerCase() == 'super_admin'
    );
  }
  
  bool get isAdmin {
    return roles.any((role) => 
      role.toLowerCase() == 'admin' || 
      role.toLowerCase() == 'administrator'
    ) || isSuperAdmin;
  }
  
  bool get isUser {
    return roles.any((role) => role.toLowerCase() == 'user') && !isAdmin;
  }
}
