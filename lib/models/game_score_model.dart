class GameScoreModel {
  final String id; // Document ID
  final int quarter; // 1, 2, 3, or 4
  final int homeScore;
  final int awayScore;
  final DateTime? createdAt;
  final bool isActive; // Whether this score is the current/active one for the quarter

  GameScoreModel({
    required this.id,
    required this.quarter,
    required this.homeScore,
    required this.awayScore,
    this.createdAt,
    this.isActive = true,
  });

  GameScoreModel copyWith({
    String? id,
    int? quarter,
    int? homeScore,
    int? awayScore,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return GameScoreModel(
      id: id ?? this.id,
      quarter: quarter ?? this.quarter,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Get the last digit of each score for squares matching
  int get homeLastDigit => homeScore % 10;
  int get awayLastDigit => awayScore % 10;

  Map<String, dynamic> toFirestore() {
    return {
      'quarter': quarter,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }

  factory GameScoreModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return GameScoreModel(
      id: documentId,
      quarter: data['quarter'] as int? ?? 1,
      homeScore: data['homeScore'] as int? ?? 0,
      awayScore: data['awayScore'] as int? ?? 0,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as dynamic).toDate() as DateTime
          : null,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'GameScoreModel(id: $id, quarter: $quarter, homeScore: $homeScore, awayScore: $awayScore, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameScoreModel &&
        other.id == id &&
        other.quarter == quarter &&
        other.homeScore == homeScore &&
        other.awayScore == awayScore &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        quarter.hashCode ^
        homeScore.hashCode ^
        awayScore.hashCode ^
        isActive.hashCode;
  }
}