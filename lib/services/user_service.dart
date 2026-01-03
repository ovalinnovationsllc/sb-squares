import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        return null;
      }

      final doc = result.docs.first;
      return UserModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      print('Error fetching user by email: $e');
      return null;
    }
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(id)
          .get();

      if (!doc.exists) {
        return null;
      }

      return UserModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  Future<bool> createUser(UserModel user) async {
    try {
      // Security logging
      print('ADMIN_ACTION: Creating user ${user.email}');
      
      // Ensure createdAt timestamp is set if not provided
      final userWithTimestamp = user.createdAt == null
          ? user.copyWith(createdAt: DateTime.now())
          : user;
      
      await _firestore
          .collection(_collection)
          .doc(userWithTimestamp.id)
          .set(userWithTimestamp.toFirestore());
      
      print('SUCCESS: User created ${user.email}');
      return true;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }
  
  Future<UserModel?> createUserWithEmail({
    required String email,
    String displayName = '',
    bool isAdmin = false,
    bool hasPaid = false,
    int numEntries = 0,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final user = UserModel(
        id: docRef.id,
        displayName: displayName,
        email: email.toLowerCase(),
        numEntries: numEntries,
        isAdmin: isAdmin,
        hasPaid: hasPaid,
        createdAt: DateTime.now(),
      );
      
      await docRef.set(user.toFirestore());
      return user;
    } catch (e) {
      print('Error creating user with email: $e');
      return null;
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(user.id)
          .update(user.toFirestore());
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  Future<bool> incrementUserEntries(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
        'numEntries': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      print('Error incrementing user entries: $e');
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();

      return result.docs.map((doc) {
        return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final users = await getAllUsers();
      
      return {
        'totalUsers': users.length,
        'paidUsers': users.where((user) => user.hasPaid).length,
        'unpaidUsers': users.where((user) => !user.hasPaid).length,
        'totalEntries': users.fold(0, (sum, user) => sum + user.numEntries),
        'adminUsers': users.where((user) => user.isAdmin).length,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  Future<bool> markInstructionsSeen(String userId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({'hasSeenInstructions': true});
      return true;
    } catch (e) {
      print('Error marking instructions as seen: $e');
      return false;
    }
  }

  Future<bool> markCoachMarksSeen(String userId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update({'hasSeenCoachMarks': true});
      return true;
    } catch (e) {
      print('Error marking coach marks as seen: $e');
      return false;
    }
  }

  Future<bool> clearAllUsers() async {
    try {
      final batch = _firestore.batch();
      
      final allUsers = await _firestore
          .collection(_collection)
          .get();

      int count = 0;
      for (final doc in allUsers.docs) {
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

      print('Cleared all users');
      return true;
    } catch (e) {
      print('Error clearing all users: $e');
      return false;
    }
  }
}