class SquareSelectionModel {
  final String id; // Document ID
  final int quarter; // 1, 2, 3, or 4
  final int row; // 0-9 (home team)
  final int col; // 0-9 (away team)
  final String userId; // User who selected this square
  final String userName; // Display name or email
  final int entryNumber; // Which entry slot (1, 2, 3, etc.) for users with multiple entries
  final DateTime? selectedAt;

  SquareSelectionModel({
    required this.id,
    required this.quarter,
    required this.row,
    required this.col,
    required this.userId,
    required this.userName,
    this.entryNumber = 1,
    this.selectedAt,
  });

  // Create a unique key for this square
  String get squareKey => '$row-$col';
  
  // Create a composite key for quarter and position
  String get compositeKey => 'Q$quarter-$row-$col';

  SquareSelectionModel copyWith({
    String? id,
    int? quarter,
    int? row,
    int? col,
    String? userId,
    String? userName,
    int? entryNumber,
    DateTime? selectedAt,
  }) {
    return SquareSelectionModel(
      id: id ?? this.id,
      quarter: quarter ?? this.quarter,
      row: row ?? this.row,
      col: col ?? this.col,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      entryNumber: entryNumber ?? this.entryNumber,
      selectedAt: selectedAt ?? this.selectedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'quarter': quarter,
      'row': row,
      'col': col,
      'userId': userId,
      'userName': userName,
      'entryNumber': entryNumber,
      'selectedAt': selectedAt ?? DateTime.now(),
      'compositeKey': compositeKey,
    };
  }

  factory SquareSelectionModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return SquareSelectionModel(
      id: documentId,
      quarter: data['quarter'] as int? ?? 1,
      row: data['row'] as int? ?? 0,
      col: data['col'] as int? ?? 0,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      entryNumber: data['entryNumber'] as int? ?? 1,
      selectedAt: data['selectedAt'] != null
          ? (data['selectedAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  @override
  String toString() {
    return 'SquareSelectionModel(id: $id, quarter: $quarter, position: ($row,$col), userId: $userId, userName: $userName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquareSelectionModel &&
        other.id == id &&
        other.quarter == quarter &&
        other.row == row &&
        other.col == col &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        quarter.hashCode ^
        row.hashCode ^
        col.hashCode ^
        userId.hashCode;
  }
}