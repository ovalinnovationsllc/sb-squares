class BoardNumbersModel {
  final String id; // Document ID
  final List<int> homeNumbers; // Randomized numbers 0-9 for home team
  final List<int> awayNumbers; // Randomized numbers 0-9 for away team
  final DateTime? randomizedAt;
  final String randomizedBy; // Admin who randomized
  final bool isActive; // Whether this is the current randomization

  BoardNumbersModel({
    required this.id,
    required this.homeNumbers,
    required this.awayNumbers,
    this.randomizedAt,
    required this.randomizedBy,
    this.isActive = true,
  });

  BoardNumbersModel copyWith({
    String? id,
    List<int>? homeNumbers,
    List<int>? awayNumbers,
    DateTime? randomizedAt,
    String? randomizedBy,
    bool? isActive,
  }) {
    return BoardNumbersModel(
      id: id ?? this.id,
      homeNumbers: homeNumbers ?? this.homeNumbers,
      awayNumbers: awayNumbers ?? this.awayNumbers,
      randomizedAt: randomizedAt ?? this.randomizedAt,
      randomizedBy: randomizedBy ?? this.randomizedBy,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'homeNumbers': homeNumbers,
      'awayNumbers': awayNumbers,
      'randomizedAt': randomizedAt ?? DateTime.now(),
      'randomizedBy': randomizedBy,
      'isActive': isActive,
    };
  }

  factory BoardNumbersModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return BoardNumbersModel(
      id: documentId,
      homeNumbers: List<int>.from(data['homeNumbers'] as List? ?? []),
      awayNumbers: List<int>.from(data['awayNumbers'] as List? ?? []),
      randomizedAt: data['randomizedAt'] != null 
          ? (data['randomizedAt'] as dynamic).toDate() as DateTime
          : null,
      randomizedBy: data['randomizedBy'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'BoardNumbersModel(id: $id, homeNumbers: $homeNumbers, awayNumbers: $awayNumbers, randomizedBy: $randomizedBy, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BoardNumbersModel &&
        other.id == id &&
        other.homeNumbers.toString() == homeNumbers.toString() &&
        other.awayNumbers.toString() == awayNumbers.toString() &&
        other.randomizedBy == randomizedBy &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        homeNumbers.hashCode ^
        awayNumbers.hashCode ^
        randomizedBy.hashCode ^
        isActive.hashCode;
  }
}