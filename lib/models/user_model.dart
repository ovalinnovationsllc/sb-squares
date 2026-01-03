class UserModel {
  final String id; // Document ID from Firestore
  final String displayName;
  final String email;
  final int numEntries;
  final bool isAdmin;
  final bool hasPaid;
  final DateTime? createdAt;
  final bool hasSeenInstructions;
  final bool emailVerified;
  final bool hasSeenCoachMarks;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    required this.numEntries,
    required this.isAdmin,
    required this.hasPaid,
    this.createdAt,
    this.hasSeenInstructions = false,
    this.emailVerified = false,
    this.hasSeenCoachMarks = false,
  });

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    int? numEntries,
    bool? isAdmin,
    bool? hasPaid,
    DateTime? createdAt,
    bool? hasSeenInstructions,
    bool? emailVerified,
    bool? hasSeenCoachMarks,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      numEntries: numEntries ?? this.numEntries,
      isAdmin: isAdmin ?? this.isAdmin,
      hasPaid: hasPaid ?? this.hasPaid,
      createdAt: createdAt ?? this.createdAt,
      hasSeenInstructions: hasSeenInstructions ?? this.hasSeenInstructions,
      emailVerified: emailVerified ?? this.emailVerified,
      hasSeenCoachMarks: hasSeenCoachMarks ?? this.hasSeenCoachMarks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'numEntries': numEntries,
      'isAdmin': isAdmin,
      'hasPaid': hasPaid,
      'createdAt': createdAt?.toIso8601String(),
      'hasSeenInstructions': hasSeenInstructions,
      'emailVerified': emailVerified,
      'hasSeenCoachMarks': hasSeenCoachMarks,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      numEntries: json['numEntries'] as int? ?? 0,
      isAdmin: json['isAdmin'] as bool? ?? false,
      hasPaid: json['hasPaid'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      hasSeenInstructions: json['hasSeenInstructions'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      hasSeenCoachMarks: json['hasSeenCoachMarks'] as bool? ?? false,
    );
  }
  
  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      numEntries: data['numEntries'] as int? ?? 0,
      isAdmin: data['isAdmin'] as bool? ?? false,
      hasPaid: data['hasPaid'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime
          : null,
      hasSeenInstructions: data['hasSeenInstructions'] as bool? ?? false,
      emailVerified: data['emailVerified'] as bool? ?? false,
      hasSeenCoachMarks: data['hasSeenCoachMarks'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'numEntries': numEntries,
      'isAdmin': isAdmin,
      'hasPaid': hasPaid,
      'createdAt': createdAt,
      'hasSeenInstructions': hasSeenInstructions,
      'emailVerified': emailVerified,
      'hasSeenCoachMarks': hasSeenCoachMarks,
    };
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, email: $email, numEntries: $numEntries, isAdmin: $isAdmin, hasPaid: $hasPaid, createdAt: $createdAt)';
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
        other.hasPaid == hasPaid &&
        other.createdAt == createdAt &&
        other.hasSeenInstructions == hasSeenInstructions &&
        other.hasSeenCoachMarks == hasSeenCoachMarks;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        displayName.hashCode ^
        email.hashCode ^
        numEntries.hashCode ^
        isAdmin.hashCode ^
        hasPaid.hashCode ^
        createdAt.hashCode ^
        hasSeenInstructions.hashCode ^
        hasSeenCoachMarks.hashCode;
  }
}