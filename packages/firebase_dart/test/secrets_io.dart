import 'dart:io';
import 'dart:convert';

Map<String, dynamic> get secrets {
  var f = File('test/secrets.json');
  if (!f.existsSync()) {
    return const {};
  }

  return json.decode(f.readAsStringSync());
}
