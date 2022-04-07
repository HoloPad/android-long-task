// ignore_for_file: avoid_print

import 'package:android_long_task/android_long_task.dart';
import 'package:android_long_task/long_task/notification_components/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@pragma('vm:entry-point')
Future<void> serviceMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  ServiceClient.setExecutionCallback((initialData) async {
    var notificationData = NotificationComponents.fromJson(initialData);
    for (var i = 0; i < 100; i++) {
      print('dart -> $i');
      notificationData.notificationDescription = i.toString();
      notificationData.barProgress = i;
      notificationData.userData?['progress'] = i;
      await ServiceClient.update(notificationData);
      await Future.delayed(const Duration(seconds: 1));
    }
    await ServiceClient.endExecution(notificationData);
    var result = await ServiceClient.stopService();
    print(result);
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'my foreground service example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'android long task example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _result = 'result';
  String _status = 'status';
  String _buttonPressed = "No button pressed";
  AppClient client = new AppClient("my_title", "my_description");

  @override
  void initState() {
    //Add here the elements that you want to show
    client.addButton(Button("myId", "myText"));
    client.initProgressBar(0, 100, false);

    client.rawUpdates.listen((json) {
      if (json != null) {
        //print("RAW DATA " + json.toString());
      }
    });
    client.userDataUpdates.listen((json) {
      if (json != null) {
        setState(() {
          _status = json.toString();
        });
      }
    });
    client.buttonUpdates.listen((buttonId) {
      print("BUTTON PRESSED " + buttonId);
      setState(() {
        _buttonPressed = "Pressed " + buttonId;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(_result,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headline6),
            const SizedBox(height: 6),
            Text(_buttonPressed),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () async {
                try {
                  client.userData = {"progress": 0};
                  var result = await client.execute();
                  if (result != null) {
                    var resultData = result['progress'];
                    setState(
                        () => _result = 'finished ' + resultData.toString());
                  }
                } on PlatformException catch (e, stacktrace) {
                  print(e);
                  print(stacktrace);
                }
              },
              child: Text('run dart function'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  var result = await client.getRawData();
                  setState(() => _result = result.toString());
                } on PlatformException catch (e, stacktrace) {
                  print(e);
                  print(stacktrace);
                }
              },
              child: const Text('get service data'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await client.stopService();
                  setState(() => _result = 'stop service');
                } on PlatformException catch (e, stacktrace) {
                  print(e);
                  print(stacktrace);
                }
              },
              child: const Text('stop service'),
            ),
          ],
        ),
      ),
    );
  }
}
