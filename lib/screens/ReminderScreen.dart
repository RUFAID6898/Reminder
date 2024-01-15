// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:reminder_app/screens/ReminderListScreen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:path/path.dart' show join;

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ReminderScreenState createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String selectedDay = "Monday";
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedActivity = "Wake up";
  late Database _database;
  List<Map<String, dynamic>> reminders = [];

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    initializeNotifications();
    initDatabase();
  }

  Future<void> loadReminders() async {
    List<Map<String, dynamic>> loadedReminders =
        await _database.query('Reminders');
    setState(() {
      reminders = loadedReminders;
    });
  }

  Future<void> initializeNotifications() async {
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('mipmap-hdpi/ic_launcher.png');
    var initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(String activity, DateTime scheduledTime) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      '2',
      'channel_name',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      icon: 'mipmap-hdpi/ic_launcher',
    );

    var platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Reminder',
      'Time for $activity!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      // ignore: deprecated_member_use
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
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

    await scheduleReminders();
  }

  Future<void> saveReminder() async {
    await _database.insert(
      'Reminders',
      {
        'day': selectedDay,
        'time': selectedTime.format(context),
        'activity': selectedActivity,
      },
    );

    await scheduleReminders();
  }

  Future<void> scheduleReminders() async {
    List<Map<String, dynamic>> reminders = await _database.query('Reminders');
    for (Map<String, dynamic> reminder in reminders) {
      String day = reminder['day'];
      String time = reminder['time'];
      String activity = reminder['activity'];

      await scheduleNotification(day, time, activity);
    }
  }

  Future<void> scheduleNotification(
      String day, String time, String activity) async {
    DateTime now = DateTime.now();
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    showNotification(activity, scheduledTime);
  }

  Future<void> removeExpiredReminder(
      String day, String time, String activity) async {
    await _database.delete(
      'Reminders',
      where: 'day = ? AND time = ? AND activity = ?',
      whereArgs: [day, time, activity],
    );

    if (mounted) {
      setState(() {
        loadReminders();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'SET YOUR REMINDER',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              Container(
                height: 100,
                width: 350,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 219, 219, 217),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: DropdownButton<String>(
                    value: selectedDay,
                    onChanged: (value) {
                      setState(() {
                        selectedDay = value!;
                      });
                    },
                    items: [
                      "Monday",
                      "Tuesday",
                      "Wednesday",
                      "Thursday",
                      "Friday",
                      "Saturday",
                      "Sunday",
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Container(
                height: 100,
                width: 350,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 219, 219, 217),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Time: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    InkWell(
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (pickedTime != null && pickedTime != selectedTime) {
                          setState(() {
                            selectedTime = pickedTime;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 253, 253),
                            borderRadius: BorderRadius.circular(10)),
                        height: 50,
                        width: 100,
                        child: Center(
                          child: Text(
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            selectedTime.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Container(
                height: 100,
                width: 350,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 219, 219, 217),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: DropdownButton<String>(
                    value: selectedActivity,
                    onChanged: (value) {
                      setState(() {
                        selectedActivity = value!;
                      });
                    },
                    items: [
                      "Wake up",
                      "Go to gym",
                      "Breakfast",
                      "Meetings",
                      "Lunch",
                      "Quick nap",
                      "Go to library",
                      "Dinner",
                      "Go to sleep",
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              InkWell(
                onTap: () async {
                  await saveReminder();

                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        // ignore: use_build_context_synchronously
                        'Reminder set for $selectedDay at ${selectedTime.format(context)}',
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 219, 219, 217),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Center(
                      child: Text(
                    'Set Reminder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  )),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ReminderListScreen()),
                  );
                },
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 219, 219, 217),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Center(
                    child: Text(
                      'View Reminders',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
