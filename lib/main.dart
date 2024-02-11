import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:health_kit_reporter/health_kit_reporter.dart';
import 'package:health_kit_reporter/model/predicate.dart';
import 'package:health_kit_reporter/model/type/workout_type.dart';
import 'package:health_kit_reporter/model/update_frequency.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

mixin HealthKitReporterMixin {
  Predicate get predicate => Predicate(
        DateTime.now().add(const Duration(hours: -24)),
        DateTime.now(),
      );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final fetchTypes = [
    HealthDataType.WORKOUT,
  ];
  List<HealthDataPoint> _healthDataList = [];
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  HealthFactory health = HealthFactory(useHealthConnectIfAvailable: true);
  final permissions = fetchTypes.map((e) => HealthDataAccess.READ).toList();

  Future authorize() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();

    // Check if we have permission
    bool? hasPermissions =
        await health.hasPermissions(fetchTypes, permissions: permissions);
    hasPermissions = false;

    bool authorized = false;
    if (!hasPermissions) {
      try {
        authorized = await health.requestAuthorization(fetchTypes,
            permissions: permissions);
      } catch (error) {
        print("Exception in authorize: $error");
      }
    }

    setState(() => print('authorized is granted'));
  }

  @override
  void initState() {
    authorize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 1,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Health Kit Reporter'),
          ),
          body: _ObserveView(),
        ),
      ),
    );
  }

  Future<void> _authorize() async {
    try {
      final readTypes = <String>[];
      readTypes.addAll(WorkoutType.values.map((e) => e.identifier));
      final writeTypes = <String>[];
      final isRequested =
          await HealthKitReporter.requestAuthorization(readTypes, writeTypes);
      print('isRequested auth: $isRequested');
    } catch (e) {
      print(e);
    }
  }
}

class _ObserveView extends StatelessWidget with HealthKitReporterMixin {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextButton(
            onPressed: () async {
              observerQuery();
            },
            child: const Text('observerQuery')),
      ],
    );
  }

  void observerQuery() async {
    List<String> identifiers = [WorkoutType.workoutType.identifier];
    try {
      final sub = HealthKitReporter.observerQuery(identifiers, null,
          onUpdate: (identifier) async {
        print('Updates for observerQuerySub - $identifier');
        queryWorkout();
      });
      print('$identifiers observerQuerySub: $sub');
      for (final identifier in identifiers) {
        final isSet = await HealthKitReporter.enableBackgroundDelivery(
            identifier, UpdateFrequency.immediate);
        print('$identifier enableBackgroundDelivery: $isSet');
      }
    } catch (e) {
      print("error = ${e}");
    }
  }

  void queryWorkout() async {
    try {
      final workouts = await HealthKitReporter.workoutQuery(predicate);
      final q = workouts[0];
      print(json.encode(q.map));
      post(q.map);
    } catch (e) {
      print(e);
    }
  }


  Future<void> post(Map<String, dynamic> data) async {
    try {
      var url = Uri.parse('https://api.twireads.ru/workout');
      var response = await http.post(
        url,
        body: {"data": json.encode([data])},
      );

      print(json.decode(utf8.decode(response.bodyBytes)));
    } catch (e) {
      print("error = ${e}");
    }
  }
}
