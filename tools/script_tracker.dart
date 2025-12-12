import 'dart:io';
import 'dart:convert';

class ScriptTracker {
  static final File _stateFile = File('.dart_tool/scripts_state.json');

  static Map<String, dynamic> _state = {};

  static Future<void> _load() async {
    if (!_stateFile.existsSync()) {
      _state = {};
      return;
    }

    final content = await _stateFile.readAsString();
    _state = jsonDecode(content);
  }

  static Future<void> _save() async {
    if (!_stateFile.parent.existsSync()) {
      _stateFile.parent.createSync(recursive: true);
    }

    await _stateFile.writeAsString(jsonEncode(_state));
  }

  static Future<bool> hasRun(String scriptName) async {
    await _load();
    return _state[scriptName] == true;
  }

  static Future<void> markAsRun(String scriptName) async {
    await _load();
    _state[scriptName] = true;
    await _save();
  }
}
