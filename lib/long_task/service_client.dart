import 'dart:convert';

import 'package:android_long_task/long_task/service_data.dart';
import 'package:flutter/services.dart';

/// [ServiceClient] is the interface you can use to controll your foreground-service
///
/// note that you can only use [ServiceClient] in `serviceMain` function you define in `lib/main.dart` of
/// your application
class ServiceClient {
  static const _CHANNEL_NAME = "APP_SERVICE_CHANNEL_NAME";
  static const _CHANNEL_NAME_IN = "APP_SERVICE_CHANNEL_NAME_OUT";
  static const _SET_SERVICE_DATA = 'SET_SERVICE_DATA';
  static const _STOP_SERVICE = 'stop_service';
  static const _END_EXECUTION = 'END_EXECUTION';
  static const _BUTTON_PRESSED_ACTION = "onButtonPressed";
  static var channel_out = MethodChannel(_CHANNEL_NAME);
  static var channel_in = MethodChannel(_CHANNEL_NAME_IN);

  /// updates shared [ServiceData] and which you can listen for on application side using [AppClient.updates] stream
  ///
  /// use this method to notify the application side on the state of the process that is running in foreground-service
  /// for example if you're downloading a file in you're foreground-service you may want to update the download progress
  /// using this method.
  static Future update(ServiceData data) async {
    var dataWrapper = ServiceDataWrapper(data);
    await channel_out.invokeMethod(_SET_SERVICE_DATA, dataWrapper.toJson());
  }

  /// set the code you want to run
  /// when foreground-service is ordered to start from application side using `AppClient.execute(serviceData)`
  /// you receive the [ServiceData] passed in that method as [initialData] in your callback
  static setExecutionCallback(Future action(Map<String, dynamic> initialData)) {
    channel_out.setMethodCallHandler((call) async {
      var json = jsonDecode(call.arguments as String);
      await action(json);
    });
  }

  /// set the code you want to run
  /// when a button in the notification is clicked
  /// you receive the buttonId[String] of the clicked button in your callback
  static setButtonClickCallback(Function(String) callback) {
    channel_in.setMethodCallHandler((call) async {
      if (call.method == _BUTTON_PRESSED_ACTION) {
        callback(call.arguments);
      }
    });
  }

  /// ends the execution of the foreground-service and return the [data] given to the application side as the result
  /// which will be received by application and passed as the return type of `AppClient.execute()` method that was
  /// called from application side.
  ///
  /// in other words that `AppClient.execute()` starts the foreground-service and with
  /// `ServiceClient.endExcution(serviceData)` we can end the execution of foreground-service and also return a [ServiceData]
  /// object as a result to application side
  static Future<void> endExecution(ServiceData data) async {
    var dataWrapper = ServiceDataWrapper(data);
    return channel_out.invokeMethod(_END_EXECUTION, dataWrapper.toJson());
  }

  /// stops service immediatly
  static Future<String?> stopService() =>
      channel_out.invokeMethod<String?>(_STOP_SERVICE);
}
