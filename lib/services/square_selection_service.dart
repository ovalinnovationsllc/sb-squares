import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/square_selection_model.dart';

class SquareSelectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'square_selections';

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

  // Add or update a square selection
  Future<bool> saveSelection({
    required int quarter,
    required int row,
    required int col,
    required String userId,
    required String userName,
  }) async {
    try {
      final compositeKey = 'Q$quarter-$row-$col';
      
      // Check if this square is already taken
      final existing = await _firestore
          .collection(_collection)
          .where('compositeKey', isEqualTo: compositeKey)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Square already taken by someone
        final existingSelection = SquareSelectionModel.fromFirestore(
          existing.docs.first.data() as Map<String, dynamic>,
          existing.docs.first.id,
        );
        
        if (existingSelection.userId != userId) {
          print('Square already taken by another user');
          return false;
        }
        
        // User is deselecting their own square
        await existing.docs.first.reference.delete();
        print('Square deselected');
        return true;
      }

      // Don't delete existing selections - users can have multiple squares per quarter
      // based on their numEntries value

      // Create new selection
      final docRef = _firestore.collection(_collection).doc();
      final selection = SquareSelectionModel(
        id: docRef.id,
        quarter: quarter,
        row: row,
        col: col,
        userId: userId,
        userName: userName,
        selectedAt: DateTime.now(),
      );

      await docRef.set(selection.toFirestore());
      print('Square selected: Q$quarter ($row,$col) by $userName');
      return true;
    } catch (e) {
      print('Error saving selection: $e');
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
}