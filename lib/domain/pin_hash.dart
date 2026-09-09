import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String hashPin(String pin, String salt) {
  final bytes = utf8.encode('$salt:$pin');
  return sha256.convert(bytes).toString();
}

String generatePinSalt() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
