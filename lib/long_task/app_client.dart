import 'dart:async';
import 'dart:convert';

import 'notification_components.dart';
import 'package:flutter/services.dart';

import 'notification_components/button.dart';

/// This is the class that you will use in  your application to communicate with foreground-service from
/// application side. like start the service, stop it, listen for [NotificationComponents] updates etc.

class AppClient {
  final _CHANNEL_NAME = 'FSE_APP_CHANNEL_NAME';
  final _START_SERVICE = 'START_SERVICE';
  final _SET_SERVICE_DATA = 'SET_SERVICE_DATA';
  final _GET_SERVICE_DATA = 'GET_SERVICE_DATA';
  final _STOP_SERVICE = 'STOP_SERVICE';
  final _RUN_DART_FUNCTION = 'RUN_DART_FUNCTION';
  final _NOTIFY_UPDATE = 'NOTIFY_UPDATE';
  final _BUTTON_CLICK = 'BUTTON_CLICK';

  // ignore: close_sinks
  final _serviceRawDataStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final _serviceUserDataStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final _buttonsEventStream = StreamController<String>.broadcast();

  late NotificationComponents _notificationComponenets;
  late MethodChannel channel;

  AppClient(String title, String description) {
    _notificationComponenets = NotificationComponents(title, description);

    channel = MethodChannel(_CHANNEL_NAME);
    channel.setMethodCallHandler((call) async {
      if (call.method == _NOTIFY_UPDATE) {
        var stringData = call.arguments as String?;
        if (stringData == null) {
          _serviceRawDataStreamController.sink.add(null);
          _serviceUserDataStreamController.sink.add(null);
        } else {
          Map<String, dynamic> json = jsonDecode(stringData);
          _serviceRawDataStreamController.sink.add(json);
          final nc = NotificationComponents.fromJson(json);
          _serviceUserDataStreamController.sink.add(nc.userData);
        }
      } else if (call.method == _BUTTON_CLICK) {
        final clickedId = call.arguments as String;
        _buttonsEventStream.sink.add(clickedId);
      }
    });
  }

  /// orders foreground-service to stop
  Future<void> stopService() async {
    await channel.invokeMethod(_STOP_SERVICE);
  }

  /// start the foreground-service and runs the code you wrote in `serviceMain` function in `lib/main.dart`
  /// Returns the [_notificationComponenets.userData] in the execution callback you set in [ServiceClient]
  Future<Map<String, dynamic>?> execute() async {
    await channel.invokeMethod(
        _SET_SERVICE_DATA, _notificationComponenets.toJson());
    await channel.invokeMethod(_START_SERVICE);
    var result = await channel.invokeMethod(_RUN_DART_FUNCTION, "");
    Map<String, dynamic> json = jsonDecode(result as String);
    final notificationComponent = NotificationComponents.fromJson(json);
    return notificationComponent.userData;
  }

  /// returns the current [NotificationComponents] object from foreground-service
  Future<Map<String, dynamic>?> getRawData() async {
    String? stringData = await channel.invokeMethod<String?>(_GET_SERVICE_DATA);
    if (stringData == null) return null;
    if (stringData.toLowerCase() == 'null') return null;
    Map<String, dynamic> json = jsonDecode(stringData);
    return json;
  }

  /// returns the current [NotificationComponents] object from foreground-service
  Future<NotificationComponents?> getNotificationData() async {
    final jsonData = await this.getRawData();
    if (jsonData == null) return null;
    return NotificationComponents.fromJson(jsonData);
  }

  /// listen for [NotificationComponents] updates from foreground service
  Stream<Map<String, dynamic>?> get rawUpdates {
    return _serviceRawDataStreamController.stream;
  }

  /// listen for [NotificationComponents] updates from foreground service
  Stream<Map<String, dynamic>?> get userDataUpdates {
    return _serviceUserDataStreamController.stream;
  }

  /// set the code you want to run
  /// when a button in the notification is clicked
  /// you receive the buttonId[String] of the clicked button in your callback
  Stream<String> get buttonUpdates {
    return _buttonsEventStream.stream;
  }

  set userData(Map<String, dynamic> userData) {
    this._notificationComponenets.userData = userData;
  }

  void initProgressBar(int progress, int maximum, bool indeterminate) {
    _notificationComponenets.initProgressBar(progress, maximum, indeterminate);
  }

  set barProgress(int progress) {
    _notificationComponenets.barProgress = progress;
  }

  set barMaximum(int maximum) {
    _notificationComponenets.barMaximum = maximum;
  }

  set barIndeterminate(bool indeterminate) {
    _notificationComponenets.barIndeterminate = indeterminate;
  }

  void addButton(Button button) {
    _notificationComponenets.addButton(button);
  }
}
