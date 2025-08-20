import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_score_model.dart';

class GameScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'game_scores';
  
  // Stream for real-time score updates
  Stream<List<GameScoreModel>> scoresStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('quarter')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return GameScoreModel.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }

  // Create or update a quarter score
  Future<bool> setQuarterScore({
    required int quarter,
    required int homeScore,
    required int awayScore,
  }) async {
    try {
      // First, deactivate any existing scores for this quarter
      await _deactivateQuarterScores(quarter);
      
      // Create new active score
      final docRef = _firestore.collection(_collection).doc();
      final score = GameScoreModel(
        id: docRef.id,
        quarter: quarter,
        homeScore: homeScore,
        awayScore: awayScore,
        createdAt: DateTime.now(),
        isActive: true,
      );
      
      await docRef.set(score.toFirestore());
      print('SUCCESS: Quarter $quarter score set - Home: $homeScore, Away: $awayScore');
      return true;
    } catch (e) {
      print('Error setting quarter score: $e');
      return false;
    }
  }

  // Get the active score for a specific quarter
  Future<GameScoreModel?> getQuarterScore(int quarter) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('quarter', isEqualTo: quarter)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        return null;
      }

      final doc = result.docs.first;
      return GameScoreModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      print('Error fetching quarter score: $e');
      return null;
    }
  }

  // Get all active quarter scores
  Future<List<GameScoreModel>> getAllQuarterScores() async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('quarter')
          .get();

      return result.docs.map((doc) {
        return GameScoreModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching all quarter scores: $e');
      return [];
    }
  }

  // Clear/deactivate a quarter score
  Future<bool> clearQuarterScore(int quarter) async {
    try {
      await _deactivateQuarterScores(quarter);
      print('SUCCESS: Quarter $quarter scores cleared');
      return true;
    } catch (e) {
      print('Error clearing quarter score: $e');
      return false;
    }
  }

  // Helper method to deactivate existing scores for a quarter
  Future<void> _deactivateQuarterScores(int quarter) async {
    final QuerySnapshot existing = await _firestore
        .collection(_collection)
        .where('quarter', isEqualTo: quarter)
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    await batch.commit();
  }

  // Calculate winners for a quarter based on score
  Map<String, dynamic> calculateQuarterWinners(GameScoreModel score) {
    final homeDigit = score.homeLastDigit;
    final awayDigit = score.awayLastDigit;
    
    // The winning square is at position [homeDigit][awayDigit]
    final winningSquare = '$homeDigit-$awayDigit';
    
    // Calculate adjacent squares (up, down, left, right)
    final adjacentSquares = <String>[];
    adjacentSquares.add('${(homeDigit + 1) % 10}-$awayDigit'); // down
    adjacentSquares.add('${(homeDigit - 1 + 10) % 10}-$awayDigit'); // up
    adjacentSquares.add('$homeDigit-${(awayDigit + 1) % 10}'); // right
    adjacentSquares.add('$homeDigit-${(awayDigit - 1 + 10) % 10}'); // left
    
    // Calculate diagonal squares
    final diagonalSquares = <String>[];
    diagonalSquares.add('${(homeDigit + 1) % 10}-${(awayDigit + 1) % 10}'); // down-right
    diagonalSquares.add('${(homeDigit + 1) % 10}-${(awayDigit - 1 + 10) % 10}'); // down-left
    diagonalSquares.add('${(homeDigit - 1 + 10) % 10}-${(awayDigit + 1) % 10}'); // up-right
    diagonalSquares.add('${(homeDigit - 1 + 10) % 10}-${(awayDigit - 1 + 10) % 10}'); // up-left
    
    return {
      'quarter': score.quarter,
      'homeScore': score.homeScore,
      'awayScore': score.awayScore,
      'homeDigit': homeDigit,
      'awayDigit': awayDigit,
      'winningSquare': winningSquare,
      'adjacentSquares': adjacentSquares,
      'diagonalSquares': diagonalSquares,
      'payouts': {
        'winner': 2400,
        'adjacent': 150,
        'diagonal': 100,
      }
    };
  }
}