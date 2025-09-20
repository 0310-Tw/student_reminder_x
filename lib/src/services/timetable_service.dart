import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimetableService {
  final String userId;
  TimetableService(this.userId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// -------------------------------
  /// TIMETABLE STRUCTURE (days & times)
  /// -------------------------------
  Future<Map<String, List<String>>> loadStructure() async {
    // Try Firestore first
    final doc = await _firestore.collection('timetable_structure').doc(userId).get();
    if (doc.exists) {
      final data = doc.data()!;
      final days = List<String>.from(data['days'] ?? []);
      final times = List<String>.from(data['times'] ?? []);
      // Save locally for offline usage
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('days', jsonEncode(days));
      prefs.setString('times', jsonEncode(times));
      return {'days': days, 'times': times};
    }

    // Fallback: local storage
    final prefs = await SharedPreferences.getInstance();
    final localDays = prefs.getString('days');
    final localTimes = prefs.getString('times');

    if (localDays != null && localTimes != null) {
      return {
        'days': List<String>.from(jsonDecode(localDays)),
        'times': List<String>.from(jsonDecode(localTimes)),
      };
    }

    // Default structure
    final defaultDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
    final defaultTimes = ["8-9", "9-10", "10-11", "11-12"];
    await saveStructure(defaultDays, defaultTimes);
    return {'days': defaultDays, 'times': defaultTimes};
  }

  Future<void> saveStructure(List<String> days, List<String> times) async {
    // Save to Firestore
    await _firestore.collection('timetable_structure').doc(userId).set({
      'days': days,
      'times': times,
    });
    // Save locally
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('days', jsonEncode(days));
    prefs.setString('times', jsonEncode(times));
  }

  /// -------------------------------
  /// USER TIMETABLE (subjects per day/time)
  /// -------------------------------
  Stream<Map<String, Map<String, String>>> getTimetableStream() {
    return _firestore
        .collection('timetable')
        .doc(userId)
        .collection('schedule')
        .snapshots()
        .map((snapshot) {
      Map<String, Map<String, String>> timetable = {};
      for (var doc in snapshot.docs) {
        final day = doc['day'] as String;
        final time = doc['time'] as String;
        final subject = doc['subject'] as String;
        timetable[day] ??= {};
        timetable[day]![time] = subject;
      }
      return timetable;
    });
  }

  Future<void> updateSubject(String day, String time, String subject) async {
    final scheduleRef =
        _firestore.collection('timetable').doc(userId).collection('schedule');

    // Check if entry exists
    final snapshot = await scheduleRef
        .where('day', isEqualTo: day)
        .where('time', isEqualTo: time)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await scheduleRef.doc(snapshot.docs.first.id).update({'subject': subject});
    } else {
      await scheduleRef.add({'day': day, 'time': time, 'subject': subject});
    }

    // Optional: save locally for offline usage
    final prefs = await SharedPreferences.getInstance();
    final key = 'timetable_$day';
    Map<String, String> dayMap = {};
    final localData = prefs.getString(key);
    if (localData != null) {
      dayMap = Map<String, String>.from(jsonDecode(localData));
    }
    dayMap[time] = subject;
    prefs.setString(key, jsonEncode(dayMap));
  }

  Future<Map<String, Map<String, String>>> loadLocalTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final structure = await loadStructure();
    Map<String, Map<String, String>> timetable = {};
    for (var day in structure['days']!) {
      final data = prefs.getString('timetable_$day');
      if (data != null) {
        timetable[day] = Map<String, String>.from(jsonDecode(data));
      } else {
        timetable[day] = {};
      }
    }
    return timetable;
  }
}
