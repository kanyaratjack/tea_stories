import 'package:flutter/material.dart';

void showLatestSnackBarOn(
  ScaffoldMessengerState? messenger,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar(reason: SnackBarClosedReason.hide)
    ..removeCurrentSnackBar(reason: SnackBarClosedReason.remove)
    ..showSnackBar(SnackBar(content: Text(message), duration: duration));
}

void showLatestSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  showLatestSnackBarOn(
    ScaffoldMessenger.maybeOf(context),
    message,
    duration: duration,
  );
}
