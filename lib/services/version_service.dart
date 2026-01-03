import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class VersionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // App version string - update this when deploying new versions
  static const String appVersion = '0.0.9';

  // Timestamp when this instance of the app was loaded
  static final DateTime _appLoadedAt = DateTime.now();

  /// Stream that emits true when an update is available
  /// (server publish time is after when this app instance loaded)
  Stream<bool> versionStream() {
    return _firestore
        .collection('config')
        .doc('app_version')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;

          final publishedAt = doc.data()?['publishedAt'] as Timestamp?;
          if (publishedAt == null) return false;

          // Show update banner if the publish time is after when we loaded
          return publishedAt.toDate().isAfter(_appLoadedAt);
        });
  }

  /// Get the last publish timestamp
  Future<DateTime?> getLastPublishTime() async {
    try {
      final doc = await _firestore.collection('config').doc('app_version').get();
      if (!doc.exists) return null;
      final publishedAt = doc.data()?['publishedAt'] as Timestamp?;
      return publishedAt?.toDate();
    } catch (e) {
      print('Error getting publish time: $e');
      return null;
    }
  }

  /// Publish an update - sets the publish timestamp to now
  /// All users who loaded the app before this time will see the update banner
  Future<bool> publishUpdate() async {
    try {
      await _firestore.collection('config').doc('app_version').set({
        'publishedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error publishing update: $e');
      return false;
    }
  }
}
