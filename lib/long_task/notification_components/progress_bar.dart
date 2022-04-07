import 'dart:convert';
import 'notification_component.dart';

class ProgressBar extends NotificationComponent {
  int progress;
  int maximum;
  bool indeterminate;

  ProgressBar(this.progress, this.maximum, this.indeterminate);

  @override
  String toJson() {
    return jsonEncode({
      "progress": progress,
      "maximum": maximum,
      "indeterminate": indeterminate
    });
  }

  static ProgressBar fromJson(Map<String, dynamic> json) {
    return ProgressBar(
        json['progress'], json['maximum'], json['indeterminate']);
  }
}
