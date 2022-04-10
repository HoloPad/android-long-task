// ignore_for_file: avoid_print

import 'package:android_long_task/android_long_task.dart';
import 'package:android_long_task/long_task/notification_components/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//this entire function runs in your ForegroundService
@pragma('vm:entry-point')
Future<void> serviceMain() async {
  //make sure you add this
  WidgetsFlutterBinding.ensureInitialized();

  ServiceClient.setExecutionCallback((initialData) async {
    //{initialData} is the data exchanged between the foreground app and your app

    ServiceClient.setOnClickCallback((buttonId) async {
      //Do something when the user click a button from notification
      await ServiceClient.stopService();
    });

    for (var i = 0; i < 100; i++) {
      print('dart -> $i');

      //Here you can change the notification texts, progress bar, ecc...
      initialData.notificationDescription = i.toString();
      initialData.barProgress = i;

      //Is it possible to exchange datas between the foreground task and the app
      //with general purpose key value registers, use serializable data
      final progress = initialData.getKeyValue("progress") as int;
      initialData.setKeyValue("progress", progress + 1);

      //Send an update from the foreground to the app
      await ServiceClient.update(initialData);
      await Future.delayed(const Duration(seconds: 1));
    }

    await ServiceClient.endExecution(initialData);
    await ServiceClient.stopService();
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

  //Create an App client instance, with the notification title and description
  //You can edit this fields later
  AppClient client = new AppClient("my_title", "my_description");

  @override
  void initState() {
    //Add here the elements that you want to show
    //Buttons
    client.addButton(Button("myId1", "myText1"));
    client.addButton(Button("myId2", "myText2"));

    //If need you can init a progressBar
    client.initProgressBar(0, 100, false);

    //Listen for the {userData} updates
    client.userDataUpdates.listen((json) {
      if (json != null) {
        setState(() {
          _status = json.toString();
        });
      }
    });

    //Listen for button clicks
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
                  //You can set userData before the foreground task execution
                  client.setKeyValue("progress", 0);
                  var result = await client.execute();
                  //Returns the userData processed by thee foreground task

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
                  //Stop the foreground task
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
