import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';

import 'package:sqflite/sqflite.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' show join;

class ReminderListScreen extends StatefulWidget {
  const ReminderListScreen({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ReminderListScreenState createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  late Database _database;
  List<Map<String, dynamic>> reminders = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    initDatabase();
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      checkAndRemoveExpiredReminders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkAndRemoveExpiredReminders() async {
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> loadedReminders =
        await _database.query('Reminders');

    List<Map<String, dynamic>> validReminders =
        loadedReminders.where((reminder) {
      String reminderTime = reminder['time'];

      TimeOfDay scheduledTime = TimeOfDay(
        hour: int.parse(reminderTime.split(':')[0]),
        minute: int.parse(reminderTime.split(':')[1].split(' ')[0]),
      );

      DateTime scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );

      return now.isBefore(scheduledDateTime);
    }).toList();

    for (Map<String, dynamic> expiredReminder in loadedReminders
        .where((reminder) => !validReminders.contains(reminder))) {
      await _database.delete(
        'Reminders',
        where: 'id = ?',
        whereArgs: [expiredReminder['id']],
      );
    }

    if (mounted) {
      setState(() {
        reminders = validReminders;
      });
    }
  }

  Future<void> initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'reminders.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE Reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day TEXT,
            time TEXT,
            activity TEXT
          )
        ''');
      },
    );

    loadReminders();
  }

  Future<void> loadReminders() async {
    List<Map<String, dynamic>> loadedReminders =
        await _database.query('Reminders');
    setState(() {
      reminders = loadedReminders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ACTIVITIES '),
      ),
      body: ListView.builder(
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          var reminder = reminders[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: ListTile(
                title: Text('${reminder['activity']}'),
                subtitle: Text('${reminder['day']} at ${reminder['time']} '),
              ),
            ),
          );
        },
      ),
    );
  }
}
