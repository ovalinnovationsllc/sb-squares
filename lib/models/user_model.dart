class UserModel {
  final String id; // Document ID from Firestore
  final String displayName;
  final String email;
  final int numEntries;
  final bool isAdmin;
  final bool isPaid;
  final DateTime? created;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    required this.numEntries,
    required this.isAdmin,
    required this.isPaid,
    this.created,
  });

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    int? numEntries,
    bool? isAdmin,
    bool? isPaid,
    DateTime? created,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      numEntries: numEntries ?? this.numEntries,
      isAdmin: isAdmin ?? this.isAdmin,
      isPaid: isPaid ?? this.isPaid,
      created: created ?? this.created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'numEntries': numEntries,
      'isAdmin': isAdmin,
      'isPaid': isPaid,
      'created': created?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      numEntries: json['numEntries'] as int? ?? 0,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isPaid: json['isPaid'] as bool? ?? false,
      created: json['created'] != null 
          ? DateTime.parse(json['created'] as String)
          : null,
    );
  }
  
  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      numEntries: data['numEntries'] as int? ?? 0,
      isAdmin: data['isAdmin'] as bool? ?? false,
      isPaid: data['isPaid'] as bool? ?? false,
      created: data['created'] != null 
          ? (data['created'] as dynamic).toDate() as DateTime
          : null,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'numEntries': numEntries,
      'isAdmin': isAdmin,
      'isPaid': isPaid,
      'created': created,
    };
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, email: $email, numEntries: $numEntries, isAdmin: $isAdmin, isPaid: $isPaid, created: $created)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.id == id &&
        other.displayName == displayName &&
        other.email == email &&
        other.numEntries == numEntries &&
        other.isAdmin == isAdmin &&
        other.isPaid == isPaid &&
        other.created == created;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        displayName.hashCode ^
        email.hashCode ^
        numEntries.hashCode ^
        isAdmin.hashCode ^
        isPaid.hashCode ^
        created.hashCode;
  }
}