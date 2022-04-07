import 'dart:convert';
import 'notification_component.dart';

class Button extends NotificationComponent {
  String id;
  String text;

  Button(this.id, this.text);

  @override
  String toJson() {
    return jsonEncode({"id": id, "text": text});
  }

  static Button fromJson(Map<String, dynamic> json) {
    return Button(json['id'], json['text']);
  }
}