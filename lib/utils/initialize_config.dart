import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../services/game_config_service.dart';

/// Run this function to initialize the config collection with default values
/// 
/// Usage: Call this once from main.dart or run as a standalone script
Future<void> initializeGameConfig() async {
  try {
    // Initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final configService = GameConfigService();
    
    // Check if config already exists
    final existingConfig = await configService.getCurrentConfig();
    
    if (existingConfig.id.isEmpty) {
      // No config exists, create default
      print('No config found. Creating default configuration...');
      
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('config').doc();
      
      await docRef.set({
        'homeTeamName': 'AFC',
        'awayTeamName': 'NFC',
        'updatedAt': DateTime.now(),
        'updatedBy': 'System',
        'isActive': true,
      });
      
      print('✅ Default config created successfully!');
      print('   Home Team: AFC');
      print('   Away Team: NFC');
    } else {
      print('✅ Config already exists:');
      print('   Home Team: ${existingConfig.homeTeamName}');
      print('   Away Team: ${existingConfig.awayTeamName}');
    }
  } catch (e) {
    print('❌ Error initializing config: $e');
  }
}

/// Standalone function to run initialization
Future<void> main() async {
  await initializeGameConfig();
}