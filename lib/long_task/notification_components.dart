import 'dart:convert';

import 'notification_components/button.dart';
import 'notification_components/progress_bar.dart';

/// [NotificationComponents] is the shared data that is passed around between foreground-service and application
/// it basically acts as both argument and result.

class NotificationComponents {
  ProgressBar? _progressBar;
  String notificationTitle;
  String notificationDescription;
  List<Button> _buttons = List.empty(growable: true);
  Map<String, dynamic> userData = Map();

  NotificationComponents(this.notificationTitle, this.notificationDescription);

  String toJson() {
    Map<String, dynamic> json = Map();
    json["notif_title"] = notificationTitle;
    json["notif_description"] = notificationDescription;
    json["notif_buttons"] = _buttons;
    json["notif_progress"] = _progressBar ?? null;
    json["user_data"] = jsonEncode(userData);
    return jsonEncode(json);
  }

  static NotificationComponents fromJson(Map<String, dynamic> json) {
    final notificationTitle = json["notif_title"];
    final notificationDescription = json["notif_description"];

    NotificationComponents data =
        NotificationComponents(notificationTitle, notificationDescription);

    final progressString = json['notif_progress'];
    if (progressString != null) {
      final progressJson = jsonDecode(progressString.toString());
      final progressObj = ProgressBar.fromJson(progressJson);
      data.initProgressBar(
          progressObj.progress, progressObj.maximum, progressObj.indeterminate);
    }

    final jsonButtons = jsonDecode(json['notif_buttons'].toString());
    final jsonButtonsList = List.from(jsonButtons);
    for (var e in jsonButtonsList) {
      data.addButton(Button.fromJson(e));
    }

    data.userData = jsonDecode(json['user_data'].toString());

    return data;
  }

  void initProgressBar(int progress, int maximum, bool indeterminate) {
    if (_progressBar == null)
      _progressBar = ProgressBar(progress, maximum, indeterminate);
  }

  set barProgress(int progress) {
    _progressBar?.progress = progress;
  }

  set barMaximum(int maximum) {
    _progressBar?.maximum = maximum;
  }

  set barIndeterminate(bool indeterminate) {
    _progressBar?.indeterminate = indeterminate;
  }

  void addButton(Button button) {
    _buttons.add(button);
  }

  void setKeyValue(String key, dynamic value){
    this.userData[key]=value;
  }

  dynamic getKeyValue(String key){
    return this.userData[key];
  }
}
