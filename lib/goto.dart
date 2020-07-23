import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'nerror.dart';

String _saveFile() {
  String home = "";
  Map<String, String> envVars = Platform.environment;
  if (Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (Platform.isLinux) {
    home = envVars['HOME'];
  } else if (Platform.isWindows) {
    // home = envVars['UserProfile'];
    // TODO: Determine save path
    throw PathException('Windows not supported');
  }
  return join(home, '.local', 'share', 'goto', 'data.json');
}

String _gotoFile() {
  String home = "";
  Map<String, String> envVars = Platform.environment;
  if (Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (Platform.isLinux) {
    home = envVars['HOME'];
  } else if (Platform.isWindows) {
    // home = envVars['UserProfile'];
    // TODO: Determine goto path
    throw PathException('Windows not supported');
  }
  return join(home, '.local', 'share', 'goto', '.goto');
}

class Goto {
  Goto._(this._dataFile, this._data);

  static Goto _cache;

  factory Goto() {
    if (_cache != null) return _cache;
    final String _savePath = _saveFile();
    final List load = _loadSync(_savePath);
    _cache = Goto._(load[0] as File, load[1] as Map<String, String>);
    return _cache;
  }

  final Map<String, String> _data;

  final File _dataFile;

  Map<String, String> get data => _data;

  // List = [File, Map]
  static List _loadSync(String path) {
    File file = File(path);
    Map<String, String> data = {};
    if (file.existsSync() == true) {
      final String _fileContent = file.readAsStringSync();
      if (_fileContent.isNotEmpty) {
        data = Map.from(
            jsonDecode(file.readAsStringSync())); // as Map<String, String>;
      }
    } else {
      file.createSync(recursive: true);
    }
    if (data == null) {
      GotoError('Unexpectedly, data is null');
    }
    return [file, data];
  }

  bool containsKey(String key) => _data.containsKey(key);

  void setKey(String key, String value) {
    final Directory dir = Directory(value);
    if (!dir.existsSync()) {
      throw FileSystemException('Not a directory', value);
    }
    _data[key] = value;
    _dataFile.writeAsStringSync(jsonEncode(_data));
  }

  void removeKey(String key) {
    if (!containsKey(key)) return null;
    _data.remove(key);
    _dataFile.writeAsStringSync(jsonEncode(_data));
  }

  String getPath(String key) {
    if (!containsKey(key)) return null;
    return _data[key];
  }

  /// Writes path to .goto file which will be picked by goto shell function
  void gotoPath(String key) {
    if (!containsKey(key)) {
      GotoError('Key "$key" not assigned to any path');
    }
    String value = _data[key];
    Directory dir = Directory(value);
    if (!dir.existsSync()) {
      GotoError('$value Directory does not exist');
    }
    File _gotofile = File(_gotoFile());
    _gotofile.createSync();
    _gotofile.writeAsStringSync(value);
    // goto function must continue from here
  }
}
