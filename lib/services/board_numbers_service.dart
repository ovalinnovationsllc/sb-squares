import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/board_numbers_model.dart';

class BoardNumbersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'board_numbers';
  
  // Stream for real-time board numbers updates
  Stream<BoardNumbersModel?> boardNumbersStream() {
    return _firestore
        .collection(_collection)
        .doc('board-numbers')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return BoardNumbersModel.fromFirestore(
        snapshot.data()!,
        snapshot.id,
      );
    });
  }

  // Get the current active board numbers
  Future<BoardNumbersModel?> getCurrentBoardNumbers() async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc('board-numbers')
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return BoardNumbersModel.fromFirestore(
        doc.data()!,
        doc.id,
      );
    } catch (e) {
      print('Error fetching current board numbers: $e');
      return null;
    }
  }

  // Generate random numbers for the board
  List<int> _generateRandomNumbers() {
    final numbers = List.generate(10, (index) => index); // [0,1,2,3,4,5,6,7,8,9]
    final random = Random();
    
    // Fisher-Yates shuffle algorithm
    for (int i = numbers.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = numbers[i];
      numbers[i] = numbers[j];
      numbers[j] = temp;
    }
    
    return numbers;
  }

  // Randomize the board numbers (admin only)
  Future<bool> randomizeBoardNumbers({
    required String adminUserId,
    required String adminName,
  }) async {
    try {
      // Generate random numbers for home and away teams
      final homeNumbers = _generateRandomNumbers();
      final awayNumbers = _generateRandomNumbers();
      
      // Always use the same fixed document ID to overwrite existing data
      final docRef = _firestore.collection(_collection).doc('board-numbers');
      final boardNumbers = BoardNumbersModel(
        id: 'board-numbers',
        homeNumbers: homeNumbers,
        awayNumbers: awayNumbers,
        randomizedAt: DateTime.now(),
        randomizedBy: adminName,
        isActive: true,
      );
      
      // Overwrite the document completely
      await docRef.set(boardNumbers.toFirestore());
      
      print('SUCCESS: Board numbers randomized by $adminName');
      print('Home numbers: $homeNumbers');
      print('Away numbers: $awayNumbers');
      print('Document ID: board-numbers (fixed)');
      
      return true;
    } catch (e) {
      print('Error randomizing board numbers: $e');
      return false;
    }
  }

  // Clear/reset board numbers (remove randomization)
  Future<bool> clearBoardNumbers() async {
    try {
      // Delete the fixed board numbers document
      await _firestore.collection(_collection).doc('board-numbers').delete();
      print('SUCCESS: Board numbers cleared');
      return true;
    } catch (e) {
      print('Error clearing board numbers: $e');
      return false;
    }
  }


  // Check if board numbers are set
  Future<bool> areBoardNumbersSet() async {
    try {
      final doc = await _firestore.collection(_collection).doc('board-numbers').get();
      return doc.exists && doc.data() != null;
    } catch (e) {
      print('Error checking if board numbers are set: $e');
      return false;
    }
  }

  // Get history of all randomizations
  Future<List<BoardNumbersModel>> getRandomizationHistory() async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .orderBy('randomizedAt', descending: true)
          .get();

      return result.docs.map((doc) {
        return BoardNumbersModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching randomization history: $e');
      return [];
    }
  }
}