import 'dart:convert';

import 'notification_components.dart';
import 'package:flutter/services.dart';

/// [ServiceClient] is the interface you can use to controll your foreground-service
///
/// note that you can only use [ServiceClient] in `serviceMain` function you define in `lib/main.dart` of
/// your application
class ServiceClient {
  static const _CHANNEL_NAME = "APP_SERVICE_CHANNEL_NAME";
  static const _SET_SERVICE_DATA = 'SET_SERVICE_DATA';
  static const _STOP_SERVICE = 'stop_service';
  static const _END_EXECUTION = 'END_EXECUTION';
  static var channel = MethodChannel(_CHANNEL_NAME);

  /// updates shared [NotificationComponents] and which you can listen for on application side using [AppClient.updates] stream
  ///
  /// use this method to notify the application side on the state of the process that is running in foreground-service
  /// for example if you're downloading a file in you're foreground-service you may want to update the download progress
  /// using this method.
  static Future update(NotificationComponents data) async {
    await channel.invokeMethod(_SET_SERVICE_DATA, data.toJson());
  }

  /// set the code you want to run
  /// when foreground-service is ordered to start from application side using `AppClient.execute(serviceData)`
  /// you receive the [NotificationComponents] passed in that method as [initialData] in your callback
  static setExecutionCallback(Future action(NotificationComponents initialData)) {
    channel.setMethodCallHandler((call) async {
      var json = jsonDecode(call.arguments as String);
      var notificationComponents = NotificationComponents.fromJson(json);
      await action(notificationComponents);
    });
  }

  /// ends the execution of the foreground-service and return the [data] given to the application side as the result
  /// which will be received by application and passed as the return type of `AppClient.execute()` method that was
  /// called from application side.
  ///
  /// in other words that `AppClient.execute()` starts the foreground-service and with
  /// `ServiceClient.endExcution(serviceData)` we can end the execution of foreground-service and also return a [NotificationComponents]
  /// object as a result to application side
  static Future<void> endExecution(NotificationComponents data) async {
    return channel.invokeMethod(_END_EXECUTION, data.toJson());
  }

  /// stops service immediatly
  static Future<String?> stopService() =>
      channel.invokeMethod<String?>(_STOP_SERVICE);
}
