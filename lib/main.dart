import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import "package:battery_plus/battery_plus.dart";
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

final battery = Battery();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

const notificationChannelId = 'my_foreground';
const notificationId = 888;

void alarmSoundToggle(play){
    if (play){
      FlutterRingtonePlayer.playAlarm();
    }
    else{
      FlutterRingtonePlayer.stop();
    }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, // id
    'MY FOREGROUND SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // await flutterLocalNotificationsPlugin
  //     .resolvePlatformSpecificImplementation<
  //         AndroidFlutterLocalNotificationsPlugin>()
  //     ?.createNotificationChannel(channel);

  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('logo');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: androidInitializationSettings);

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    alarmSoundToggle(false);
    print("Clicked on notification");
  }

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

  service.configure(
      iosConfiguration: IosConfiguration(
          onBackground: null, autoStart: false, onForeground: null),
      androidConfiguration: AndroidConfiguration(
        autoStartOnBoot: false,
        notificationChannelId: notificationChannelId,
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        initialNotificationTitle: 'Battery Alarm',
        initialNotificationContent: 'Service running in background',
      ));
}

void onStart(ServiceInstance service) async {
  print("Service started");
  periodicCheck();
  service.on('stopService').listen((event) {
    print("Stopping service");
    service.stopSelf();
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? info;
  bool alarmVisible = false;
  List dataList = [];
  List<Widget> InfoList = [];
  bool serviceEnabled = false;
  String serviceStatusTxt = "Service is disabled";

  @override
  void initState() {
    super.initState();
    getInfo();
  }

  void getServiceStatus() async {
    SharedPreferences storage = await SharedPreferences.getInstance();
    String? data = storage.getString("serviceEnabled");
    if (data != "" && data != null) {
      setState(() {
        serviceEnabled = bool.fromEnvironment(data);
      });
    }
  }

  void toggleServiceStatus() async {
    final service = FlutterBackgroundService();
    SharedPreferences storage = await SharedPreferences.getInstance();
    setState(() {
      serviceEnabled = !serviceEnabled;
      if (serviceEnabled) {
        serviceStatusTxt = "Service is enabled";
      } else {
        serviceStatusTxt = "Service is disabled";
      }
    });
    if (serviceEnabled) {
      service.startService();
    } else {
      service.invoke("stopService");
      alarmSoundToggle(false);
    }

    await storage.setString("serviceEnabled", jsonEncode(serviceEnabled));
  }

  void addToStorage(info) async {
    SharedPreferences storage = await SharedPreferences.getInstance();
    var encoded = jsonEncode(info);
    await storage.setString("data", encoded);
  }

  void changeAlarmVisibility() {
    setState(() {
      alarmVisible = !alarmVisible;
    });
  }

  getInfo() async {
    SharedPreferences storage = await SharedPreferences.getInstance();
    info = storage.getString("data");
    print(info.runtimeType);
    if (info != "" && info != null) {
      dataList = jsonDecode(info!);
      setState(() {
        InfoList = dataList.map((item) => Item(info: item)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Info: $InfoList");

    return MaterialApp(
      title: "Battery Alarm",
      theme: ThemeData(brightness: Brightness.dark),
      // darkTheme: ThemeData(brightness: Brightness.dark),
      debugShowMaterialGrid: false,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 75,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Battery Alarm"),
              IconButton(
                  iconSize: 35,
                  onPressed: () {
                    alarmSoundToggle(false);
                  },
                  icon: const Icon(
                    Icons.more_vert,
                  ))
            ],
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        serviceStatusTxt,
                        style: const TextStyle(fontSize: 24),
                      ),
                      Switch(
                        value: serviceEnabled,
                        onChanged: (value) {
                          toggleServiceStatus();
                        },
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  ...InfoList,
                ],
              ),
            ),
            Visibility(
              visible: alarmVisible,
              child: Stack(
                children: [
                  InkWell(
                    onTap: changeAlarmVisibility,
                    child: Container(
                      color: const Color.fromARGB(168, 42, 42, 42),
                    ),
                  ),
                  AlarmBox(changeAlarmVisibility, getInfo)
                ],
              ),
            )
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: IconButton(
            iconSize: 95,
            onPressed: changeAlarmVisibility,
            icon: const Icon(Icons.add_circle)),
      ),
    );
  }
}

class Item extends StatefulWidget {
  var info;
  var enabled;

  Item({var this.info}) {
    enabled = info["enabled"];
  }

  @override
  State<Item> createState() => _ItemState();
}

class _ItemState extends State<Item> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  void toggle() {
    setState(() {
      _enabled = !_enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.all(Radius.circular(25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.info["level"]}%",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 35),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.info["state"],
                style: const TextStyle(
                  fontSize: 22,
                ),
              ),
              Switch(value: _enabled, onChanged: ((value) => {toggle()})),
            ],
          )
        ],
      ),
    );
  }
}

void periodicCheck() {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer.periodic(const Duration(seconds: 20), (timer) async {
    final percentage = await battery.batteryLevel;
    SharedPreferences storage = await SharedPreferences.getInstance();
    String? storageData = storage.getString("data");

    if (storageData != "" && storageData != null) {}
    List storageDataList = [];

    if (storageData != null && storageData != "") {
      storageDataList = jsonDecode(storageData);
    }

    for (var item in storageDataList) {
      print(item);

      if (item["enabled"] == true) {
        if (item["state"] == "When Charging") {
          if (percentage == item["level"]) {
            alarmSoundToggle(true);
            flutterLocalNotificationsPlugin.show(
                notificationId,
                'Battery Alarm',
                'Plugin or unplug your phone!',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                      notificationChannelId, 'MY FOREGROUND SERVICE',
                      icon: 'ic_bg_service_small',
                      ongoing: true,
                      fullScreenIntent: true,
                      actions: [
                        AndroidNotificationAction(
                            notificationChannelId, "Disable")
                      ]),
                ));
            break;
          }
        }
        // When not charging
        else {
          if (percentage == item["level"]) {
            alarmSoundToggle(true);
            flutterLocalNotificationsPlugin.show(
                notificationId,
                'Battery Alarm',
                'Plugin or unplug your phone!',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    notificationChannelId,
                    'MY FOREGROUND SERVICE',
                    icon: 'ic_bg_service_small',
                    ongoing: true,
                  ),
                ));
            break;
          }
        }
      }
    }

    print("Battery: $percentage%");
  });
}

class AlarmBox extends StatefulWidget {
  var changeVisibility;
  var batteryInput;
  var triggerState = 0;
  var getInfo;

  AlarmBox(changeAlarmVisibility, getInfo) {
    this.changeVisibility = changeAlarmVisibility;
    this.getInfo = getInfo;
  }

  @override
  State<AlarmBox> createState() => _AlarmBoxState();
}

class _AlarmBoxState extends State<AlarmBox> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color.fromARGB(255, 60, 60, 60),
                borderRadius: BorderRadius.all(Radius.circular(15))),
            width: 360,
            height: 500,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Choose Battery level",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Battery Level"),
                    onChanged: (text) {
                      widget.batteryInput = text;
                    }),
                const SizedBox(
                  height: 20,
                ),
                const Text("Trigger Alarm When",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                DropdownButton(
                  value: widget.triggerState,
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Charging'),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Unplugged'),
                    )
                  ],
                  onChanged: (value) {
                    setState(() => {widget.triggerState = value!});
                  },
                ),
                ElevatedButton(
                    onPressed: () async {
                      int? batteryLevel = int.tryParse(widget.batteryInput);
                      if (batteryLevel != null &&
                          batteryLevel > 0 &&
                          batteryLevel <= 100) {
                        SharedPreferences storage =
                            await SharedPreferences.getInstance();
                        final service = FlutterBackgroundService();

                        String? storageData = storage.getString("data");
                        List storageDataList = [];
                        if (storageData != null && storageData != "") {
                          storageDataList = jsonDecode(storageData);
                        }
                        String state;
                        if (widget.triggerState == 0) {
                          state = "When Charging";
                        } else {
                          state = "When Unplugged";
                        }

                        Map alarmObject = {
                          "id":
                              Random().nextDouble().toString().substring(2, 12),
                          "level": batteryLevel,
                          "state": state,
                          "enabled": true
                        };
                        storageDataList.add(alarmObject);
                        print("Adding $alarmObject");
                        await storage.setString(
                            "data", jsonEncode(storageDataList));
                        widget.changeVisibility();
                        widget.getInfo();
                      } else {
                        // Show error message
                      }
                    },
                    child: const Text(
                      "Create Alarm",
                      style: TextStyle(fontSize: 20),
                    )),
              ],
            )));
  }
}
