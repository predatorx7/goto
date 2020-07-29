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
    // TODO: Determine save path for windows
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
    // TODO: Determine goto file path for windows
    GotoError.exit('Windows not supported');
  }
  return join(home, '.local', 'share', 'goto', '.goto');
}

class _Goto {
  /// This constructor is meant to be used by the public factory
  const _Goto._(this._dataFile, this._data);

  /// Stores a singleton instance of this class
  static _Goto _cache;

  /// Returns a Goto class singleton
  factory _Goto() {
    if (_cache != null) return _cache;
    final String _savePath = _saveFile();

    /// Load & return storage file and data synchronously
    final List load = _loadSync(_savePath);

    /// Create an instance of Goto with data above
    _cache = _Goto._(load[0] as File, load[1] as Map<String, String>);
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

  /// Writes latest k-v [_data] to [_dataFile]
  void _save() {
    _dataFile.writeAsStringSync(jsonEncode(_data));
  }

  void _keyAlreadyExists(String key) {
    if (_data.containsKey(key)) {
      // Key already exists in the save file
      stdout.write(
          "A path saved with '$key' already exists. This will remove '${_data[key]}' from entries.\nDo you wish to continue? (Y/n): ");
      // Ask user for a response
      var reply = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
      if (!['Y', 'y'].contains(reply[0])) {
        // User does not wish to continue. exit.
        exit(0);
      }
    }
  }

  /// Check if key exists in save file (_data map is used as it's in sync with save
  /// file)
  bool containsKey(String key) => _data.containsKey(key);

  /// Saves a key-path pair in save file
  void setKey(String key, String value) {
    final Directory dir = Directory(value);
    if (!dir.existsSync()) {
      GotoError.warn(
          "'$value' not found. It either does not exist or is not a directory.");
    }
    _keyAlreadyExists(key);
    _data[key] = value;
    _save();
  }

  /// Remove all data from save file
  void removeAll() {
    _data.clear();
    _save();
  }

  void rename(String oldKey, String newKey) {
    if (!_data.containsKey(oldKey)) return null;
    _keyAlreadyExists(newKey);
    _data[newKey] = _data[oldKey];
    _data.remove(oldKey);
    _save();
  }

  /// Remove a key from save file
  void removeKey(String key) {
    if (!containsKey(key)) return null;
    _data.remove(key);
    _save();
  }

  /// Returns path with key
  String getPath(String key) {
    if (!containsKey(key)) return null;
    return _data[key];
  }

  /// Writes path to .goto file which will be picked by goto shell function
  void gotoPath(String key) {
    if (!containsKey(key)) {
      GotoError("Key '$key' not assigned to any path");
    }
    String value = _data[key];
    Directory dir = Directory(value);
    if (!dir.existsSync()) {
      GotoError.warn(
          "'$value' not found. It either does not exist or is not a directory.");
    }
    File _gotofile = File(_gotoFile());
    try {
      _gotofile.createSync();
    } catch (e) {
      GotoError('An unexpected error occurred');
    }
    _gotofile.writeAsStringSync(value);
    // goto function must continue from here
  }
}

final _Goto Goto = _Goto();
