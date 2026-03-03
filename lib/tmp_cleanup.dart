import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final db = FirebaseDatabase.instance;
  final matches = db.ref('matches');
  
  print('Cleaning up stale matches...');
  await matches.child('RHY17001').remove();
  await matches.child('ZIM64878').remove();
  print('Cleanup complete.');
}
