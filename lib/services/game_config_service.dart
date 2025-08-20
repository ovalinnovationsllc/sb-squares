import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_config_model.dart';

class GameConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'config';
  
  // Stream for real-time config updates
  Stream<GameConfigModel> configStream() {
    return _firestore
        .collection(_collection)
        .doc('game-config')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        // Return default config if document doesn't exist
        return GameConfigModel.defaultConfig();
      }
      return GameConfigModel.fromFirestore(
        snapshot.data()!,
        snapshot.id,
      );
    });
  }

  // Get current active configuration
  Future<GameConfigModel> getCurrentConfig() async {
    try {
      // Use the fixed document ID
      final docRef = _firestore.collection(_collection).doc('game-config');
      final doc = await docRef.get();

      if (!doc.exists) {
        // Create default config if none exists
        await createDefaultConfig();
        return GameConfigModel.defaultConfig();
      }

      return GameConfigModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      print('Error fetching config: $e');
      return GameConfigModel.defaultConfig();
    }
  }

  // Create default configuration only if none exists
  Future<bool> createDefaultConfig() async {
    try {
      print('🔧 Checking game configuration...');
      
      // Check if config already exists
      final docRef = _firestore.collection(_collection).doc('game-config');
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('✅ Config already exists:');
        print('   Home Team: ${data['homeTeamName']}');
        print('   Away Team: ${data['awayTeamName']}');
        return true;
      }
      
      // Create default config only if it doesn't exist
      final configData = {
        'homeTeamName': 'AFC',
        'awayTeamName': 'NFC',
        'updatedAt': DateTime.now(),
        'updatedBy': 'System - Initialize',
        'isActive': true,
      };
      
      await docRef.set(configData);
      print('✅ Config collection created successfully!');
      print('   Document ID: game-config');
      print('   Home Team: AFC');
      print('   Away Team: NFC');
      
      return true;
    } catch (e) {
      print('❌ Error creating config: $e');
      return false;
    }
  }

  // Force initialize - call this if config doesn't seem to exist
  Future<void> forceInitializeConfig() async {
    try {
      print('🚀 Force creating config collection...');
      await createDefaultConfig();
      print('✅ Config force-created. Collection should now exist in Firestore.');
    } catch (e) {
      print('❌ Force initialization failed: $e');
    }
  }

  // Update team names (admin only)
  Future<bool> updateTeamNames({
    required String homeTeamName,
    required String awayTeamName,
    required String updatedBy,
  }) async {
    try {
      print('🔄 Updating team names...');
      
      // Always use the fixed document ID for updates
      final docRef = _firestore.collection(_collection).doc('game-config');
      
      // Update the existing document
      await docRef.update({
        'homeTeamName': homeTeamName.trim(),
        'awayTeamName': awayTeamName.trim(),
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
        'isActive': true,
      });

      print('✅ Team names updated successfully:');
      print('   Home Team: $homeTeamName');
      print('   Away Team: $awayTeamName');
      print('   Updated by: $updatedBy');
      
      return true;
    } catch (e) {
      print('❌ Error updating team names: $e');
      
      // Fallback: try to create the document if it doesn't exist
      try {
        print('🔄 Attempting to create config document...');
        final docRef = _firestore.collection(_collection).doc('game-config');
        
        await docRef.set({
          'homeTeamName': homeTeamName.trim(),
          'awayTeamName': awayTeamName.trim(),
          'updatedAt': DateTime.now(),
          'updatedBy': updatedBy,
          'isActive': true,
        });
        
        print('✅ Config created with team names update');
        return true;
      } catch (e2) {
        print('❌ Fallback failed: $e2');
        return false;
      }
    }
  }

  // Validate team names
  bool validateTeamNames(String homeTeam, String awayTeam) {
    if (homeTeam.trim().isEmpty || awayTeam.trim().isEmpty) {
      return false;
    }
    if (homeTeam.trim().length > 20 || awayTeam.trim().length > 20) {
      return false; // Max length for display purposes
    }
    return true;
  }
}