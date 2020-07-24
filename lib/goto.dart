import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'nerror.dart';

/// Returns path for save file for this platform & user
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
    GotoError.exit('Windows not supported');
  }
  return join(home, '.local', 'share', 'goto', 'data.json');
}

/// Returns path for temp file for this platform & user which
/// will be used by goto function to navigate.
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
    GotoError.exit('Windows not supported');
  }
  return join(home, '.local', 'share', 'goto', '.goto');
}

class Goto {
  /// This constructor is meant to be used by the public factory
  Goto._(this._dataFile, this._data);

  /// Stores a singleton instance of this class
  static Goto _cache;

  /// Returns a Goto class singleton
  factory Goto() {
    if (_cache != null) return _cache;
    final String _savePath = _saveFile();

    /// Load & return storage file and data synchronously
    final List load = _loadSync(_savePath);

    /// Create an instance of Goto with data above
    _cache = Goto._(load[0] as File, load[1] as Map<String, String>);
    return _cache;
  }

  /// The data which is synced with the save file.
  final Map<String, String> _data;

  /// The save file where the data will be persisted
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

  /// Check if key exists in save file (_data map is used as it's in sync with save
  /// file)
  bool containsKey(String key) => _data.containsKey(key);

  /// Saves a key-path pair in save file
  void setKey(String key, String value) {
    final Directory dir = Directory(value);
    if (!dir.existsSync()) {
      GotoError.warn(
          '"$value" not found. It either does not exist or is not a directory.');
    }
    _data[key] = value;
    _dataFile.writeAsStringSync(jsonEncode(_data));
  }

  /// Remove all data from save file
  void removeAll() {
    _data.clear();
    _dataFile.writeAsStringSync(jsonEncode(_data));
  }

  /// Remove a key from save file
  void removeKey(String key) {
    if (!containsKey(key)) return null;
    _data.remove(key);
    _dataFile.writeAsStringSync(jsonEncode(_data));
  }

  /// Returns path with key
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
      GotoError.warn(
          '"$value" not found. It either does not exist or is not a directory.');
    }
    File _gotofile = File(_gotoFile());
    _gotofile.createSync();
    _gotofile.writeAsStringSync(value);
    // goto function must continue from here
  }
}
