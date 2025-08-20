#!/usr/bin/env dart

/// Standalone script to create the config collection in Firestore
/// Run this script with: dart scripts/create_config.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/firebase_options.dart';

Future<void> main() async {
  print('🚀 Initializing Firebase...');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Check if config collection exists
    print('📋 Checking for existing config...');
    final configQuery = await firestore
        .collection('config')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    
    if (configQuery.docs.isNotEmpty) {
      final existingConfig = configQuery.docs.first.data();
      print('✅ Config already exists:');
      print('   Home Team: ${existingConfig['homeTeamName']}');
      print('   Away Team: ${existingConfig['awayTeamName']}');
      print('   Last Updated: ${existingConfig['updatedAt']?.toDate()}');
      print('   Updated By: ${existingConfig['updatedBy']}');
    } else {
      print('📝 No active config found. Creating default configuration...');
      
      // Create new config document
      final docRef = firestore.collection('config').doc();
      
      final configData = {
        'homeTeamName': 'AFC',
        'awayTeamName': 'NFC',
        'updatedAt': DateTime.now(),
        'updatedBy': 'System - Initial Setup',
        'isActive': true,
      };
      
      await docRef.set(configData);
      
      print('✅ Config created successfully!');
      print('   Document ID: ${docRef.id}');
      print('   Home Team: AFC');
      print('   Away Team: NFC');
      print('');
      print('🎯 You can now:');
      print('   1. Check Firebase Console to see the config collection');
      print('   2. Use the Admin Dashboard to change team names');
      print('   3. Team names will update in real-time for all users');
    }
  } catch (e) {
    print('❌ Error: $e');
    print('');
    print('🔧 Troubleshooting:');
    print('   1. Make sure Firebase is properly configured');
    print('   2. Check your internet connection');
    print('   3. Verify Firebase project settings in firebase_options.dart');
  }
  
  print('');
  print('✨ Done!');
}