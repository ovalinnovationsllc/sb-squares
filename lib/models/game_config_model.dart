class GameConfigModel {
  final String id;
  final String homeTeamName;
  final String awayTeamName;
  final DateTime? updatedAt;
  final String? updatedBy;
  final bool isActive;

  GameConfigModel({
    required this.id,
    required this.homeTeamName,
    required this.awayTeamName,
    this.updatedAt,
    this.updatedBy,
    this.isActive = true,
  });

  // Convert model to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'homeTeamName': homeTeamName,
      'awayTeamName': awayTeamName,
      'updatedAt': updatedAt ?? DateTime.now(),
      'updatedBy': updatedBy ?? '',
      'isActive': isActive,
    };
  }

  // Create model from Firestore document
  factory GameConfigModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GameConfigModel(
      id: id,
      homeTeamName: data['homeTeamName'] ?? 'AFC',
      awayTeamName: data['awayTeamName'] ?? 'NFC',
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as dynamic).toDate() 
          : null,
      updatedBy: data['updatedBy'],
      isActive: data['isActive'] ?? true,
    );
  }

  // Create default config
  factory GameConfigModel.defaultConfig() {
    return GameConfigModel(
      id: '',
      homeTeamName: 'AFC',
      awayTeamName: 'NFC',
      updatedAt: DateTime.now(),
      isActive: true,
    );
  }
}