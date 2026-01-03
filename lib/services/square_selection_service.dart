import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/square_selection_model.dart';

class SquareSelectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'square_selections';

  /// Count unique squares selected (unique row-col combinations)
  /// This represents how many of the 100 board positions are claimed
  Future<int> getUniqueSquaresCount() async {
    try {
      // Get Q1 selections - these represent the unique squares claimed
      // (each position in Q1 = one unique entry on the board)
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('quarter', isEqualTo: 1)
          .get();
      return result.docs.length;
    } catch (e) {
      print('Error counting unique squares: $e');
      return 0;
    }
  }

  // Stream for real-time updates
  Stream<List<SquareSelectionModel>> selectionsStream() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SquareSelectionModel.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    });
  }

  // Get all selections for a specific quarter
  Future<List<SquareSelectionModel>> getQuarterSelections(int quarter) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('quarter', isEqualTo: quarter)
          .get();

      return result.docs.map((doc) {
        return SquareSelectionModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching quarter selections: $e');
      return [];
    }
  }

  // Get all selections for all quarters
  Future<Map<int, List<SquareSelectionModel>>> getAllSelections() async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .get();

      final Map<int, List<SquareSelectionModel>> selections = {};
      
      for (int i = 1; i <= 4; i++) {
        selections[i] = [];
      }

      for (final doc in result.docs) {
        final selection = SquareSelectionModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        selections[selection.quarter]?.add(selection);
      }

      return selections;
    } catch (e) {
      print('Error fetching all selections: $e');
      return {1: [], 2: [], 3: [], 4: []};
    }
  }

  // Get selections for a specific user
  Future<List<SquareSelectionModel>> getUserSelections(String userId) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      return result.docs.map((doc) {
        return SquareSelectionModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching user selections: $e');
      return [];
    }
  }

  // Add or update a square selection with transaction for collision prevention
  Future<bool> saveSelection({
    required int quarter,
    required int row,
    required int col,
    required String userId,
    required String userName,
    required int entryNumber,
  }) async {
    try {
      // Use compositeKey as document ID to ensure atomic operations
      final compositeKey = 'Q$quarter-$row-$col';
      final docRef = _firestore.collection(_collection).doc(compositeKey);

      // Use a transaction with document-level locking to prevent race conditions
      return await _firestore.runTransaction<bool>((transaction) async {
        // Read the specific document within the transaction
        final docSnapshot = await transaction.get(docRef);

        if (docSnapshot.exists) {
          // Square already exists
          final existingSelection = SquareSelectionModel.fromFirestore(
            docSnapshot.data()!,
            docSnapshot.id,
          );

          if (existingSelection.userId != userId) {
            // Square taken by another user - transaction will fail
            print('Square already taken by ${existingSelection.userName}');
            return false;
          }

          // User is deselecting their own square
          transaction.delete(docRef);
          print('Square deselected in transaction');
          return true;
        }

        // Square is available - create new selection
        final selection = SquareSelectionModel(
          id: compositeKey,
          quarter: quarter,
          row: row,
          col: col,
          userId: userId,
          userName: userName,
          entryNumber: entryNumber,
          selectedAt: DateTime.now(),
        );

        transaction.set(docRef, selection.toFirestore());
        print('Square selected in transaction: Q$quarter ($row,$col) by $userName (entry #$entryNumber)');
        return true;
      });
    } catch (e) {
      print('Transaction error saving selection: $e');
      return false;
    }
  }

  // Remove a specific selection
  Future<bool> removeSelection(String selectionId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(selectionId)
          .delete();
      return true;
    } catch (e) {
      print('Error removing selection: $e');
      return false;
    }
  }

  // Clear all selections for a specific quarter
  Future<bool> clearQuarterSelections(int quarter) async {
    try {
      final batch = _firestore.batch();
      
      final selections = await _firestore
          .collection(_collection)
          .where('quarter', isEqualTo: quarter)
          .get();

      for (final doc in selections.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleared all selections for quarter $quarter');
      return true;
    } catch (e) {
      print('Error clearing quarter selections: $e');
      return false;
    }
  }

  // Clear ALL selections (admin only)
  Future<bool> clearAllSelections() async {
    try {
      final batch = _firestore.batch();
      
      final allSelections = await _firestore
          .collection(_collection)
          .get();

      int count = 0;
      for (final doc in allSelections.docs) {
        batch.delete(doc.reference);
        count++;
        
        // Firestore batch limit is 500 operations
        if (count >= 500) {
          await batch.commit();
          // Start a new batch if needed
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      print('Cleared all square selections');
      return true;
    } catch (e) {
      print('Error clearing all selections: $e');
      return false;
    }
  }

  // Get count of selections per quarter
  Future<Map<int, int>> getSelectionCounts() async {
    try {
      final selections = await getAllSelections();
      return {
        1: selections[1]?.length ?? 0,
        2: selections[2]?.length ?? 0,
        3: selections[3]?.length ?? 0,
        4: selections[4]?.length ?? 0,
      };
    } catch (e) {
      print('Error getting selection counts: $e');
      return {1: 0, 2: 0, 3: 0, 4: 0};
    }
  }

  // Check if all squares are filled (100 squares per quarter)
  Future<bool> isBoardFull() async {
    try {
      final counts = await getSelectionCounts();
      return counts.values.every((count) => count >= 100);
    } catch (e) {
      print('Error checking if board is full: $e');
      return false;
    }
  }

  // Get total number of selections across all quarters
  Future<int> getTotalSelections() async {
    try {
      final counts = await getSelectionCounts();
      return counts.values.fold<int>(0, (sum, count) => sum + count);
    } catch (e) {
      print('Error getting total selections: $e');
      return 0;
    }
  }
}