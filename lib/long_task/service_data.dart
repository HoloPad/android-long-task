import 'dart:convert';

/// [ServiceData] is the shared data that is passed around between foreground-service and application
/// it basically acts as both argument and result.
///
/// you create an implementation of [ServiceData] that you need then you pass it around between foreground-service
/// and application. this how foreground-service and application communicate to each other
abstract class ServiceData {
  String toJson();

  String get notificationTitle;

  String get notificationDescription;

  List<Button> get buttons;
}

class Button {
  String id;
  String text;

  Button(this.id, this.text);

  String toJson(){
    return jsonEncode({
      "id":id,
      "text":text
    });
  }
}

/// this class is only visible for internal usage in package
class ServiceDataWrapper {
  ServiceData _serviceData;

  ServiceDataWrapper(this._serviceData);

  String toJson() {
    Map<String, dynamic> json = jsonDecode(_serviceData.toJson());
    json["notif_title"] = _serviceData.notificationTitle;
    json["notif_description"] = _serviceData.notificationDescription;
    json["notif_buttons"] = _serviceData.buttons;
    return jsonEncode(json);
  }
}
