import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:goto/goto.dart';
import 'package:goto/nerror.dart';

const List<String> _illegalKeyNames = <String>[
  'g',
  'get',
  'ls',
  'l',
  'list',
  're',
  'rename',
  'rm',
  'r',
  'remove',
  'save',
  's',
  'set',
];

void isKeyValid(String key) {
  if (!RegExp(r'^\w*$').hasMatch(key)) {
    GotoError.warn(
        "'$key' has invalid format. Key must only contain alphabet, underscore, or numbers");
    return;
  }
  if (_illegalKeyNames.contains(key)) {
    GotoError.warn(
        "'$key' is invalid. Key must not be the name or alias of any goto command.");
    return;
  }
}

/// When no other commands are executed then the argument specifies a &lt;key&gt;
///
/// That &lt;key&gt; represents a path and if it's valid and exists, this will
/// save a temporary file with that &lt;key&gt;'s path as content.
///
/// The goto function sourced in shell config file will change directory to
/// that path if the temporary file exists.
class GoCommand {
  final List<String> arguments;
  final CommandRunner parser;

  const GoCommand(this.arguments, this.parser);

  bool get valid {
    return arguments.length == 1;
  }

  void run() {
    if (!valid) throw Exception('Invalid Arguments\n${parser.usage}');
    final String key = arguments.first;
    Goto.gotoPath(key);
  }
}

abstract class ExtendedCommand extends Command<String> {
  String get listAlias =>
      aliases.isEmpty ? '' : '\nOther alias: ${aliases.join(', ')}\n';

  @override
  String get description;

  @override
  String get name;

  /// A single-line template for how to invoke this command (e.g. "pub getpackage").
  String get usageInvocation;

  @override
  String get invocation => '$usageInvocation$listAlias';
}

class RenameCommand extends ExtendedCommand {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "rename";
  @override
  final description = "Renames a key.";

  RenameCommand();

  @override
  String get usageInvocation =>
      'goto rename <previous_key_name> <new_key_name>';

  @override
  List<String> get aliases => ['re'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    if ((argResults.rest?.isEmpty ?? true) ||
        (argResults.rest?.length ?? 0) < 2) {
      GotoError.missing(usage);
    }
    final String previousKeyName = argResults.rest[0];
    final String newKeyName = argResults.rest[1];
    // Check if previousKeyExists, else throw KeyNotFound
    if (!Goto.containsKey(previousKeyName)) {
      GotoError("Found no path with '$previousKeyName' key");
      return null;
    }
    if (previousKeyName == newKeyName) {
      GotoError.exit('Error: Old & new key names must not be same.');
    }
    // If exists, remove that key and replace it with new key-name else.
    isKeyValid(newKeyName);
    print("Renaming key '$previousKeyName' with '$newKeyName'.. ");
    Goto.rename(previousKeyName, newKeyName);
  }
}

/// Saves a path with key
class SetCommand extends ExtendedCommand {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "set";
  @override
  final description = "Saves a path with a key.";

  SetCommand();

  @override
  String get usageInvocation => 'goto set <key> <path>';

  @override
  List<String> get aliases => ['save', 's'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    if (argResults.rest?.isEmpty ?? true) {
      GotoError.missing(usage);
    }
    String key = argResults.rest[0];
    isKeyValid(key);
    String value = (argResults.rest.length == 1)
        ? Directory.current.path
        : argResults.rest[1];
    if (value == '.') {
      value = Directory.current.path;
    }
    print('Saving "$value" with key "$key".. ');
    Goto.setKey(key, value);
  }
}

/// Retrieves and prints a path for a key
class GetCommand extends ExtendedCommand {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "get";
  @override
  final description = "Gets a path address matching the key";

  GetCommand();

  @override
  String get usageInvocation => 'goto get <key>';

  @override
  List<String> get aliases => ['g'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    // [argResults] is set before [run()] is called and contains the options
    // passed to this command.
    if (argResults.rest?.isEmpty ?? true) {
      GotoError.missing(usage);
    }
    String key = argResults.rest[0];
    String reply = Goto.getPath(key);
    if (reply == null) {
      GotoError("Found no path with '$key' key");
    }
    print('$key -> ${reply}');
  }
}

/// Remove a saved key-path or remove all saved key-paths
class RemoveCommand extends ExtendedCommand {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "remove";
  @override
  final description = "Removes a record matching the key";

  RemoveCommand() {
    // [argParser] is automatically created by the parent class.
    argParser.addFlag('all',
        abbr: 'a', help: 'Remove all saved key-value records');
  }

  @override
  String get usageInvocation => 'goto remove <key>';

  @override
  List<String> get aliases => ['rm', 'r'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    if (argResults['all']) {
      // remove all
      Goto.removeAll();
      return null;
    }
    if (argResults.rest?.isEmpty ?? true) {
      GotoError.missing(usage);
    }
    // [argResults] is set before [run()] is called and contains the options
    // passed to this command.
    Goto.removeKey(argResults.rest[0]);
  }
}

/// Lists all saved key-path pairs in human readable format
class ListCommand extends ExtendedCommand {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = 'list';
  @override
  final description = "List all saved records in a human readable format";

  ListCommand();

  @override
  bool get takesArguments => false;

  @override
  String get usageInvocation => 'goto list';

  @override
  List<String> get aliases => ['ls', 'l'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    Map data = Goto.data;
    if (data.isEmpty) {
      print('No saved records');
      return null;
    }
    for (var item in data.keys) {
      print('$item: ${data[item]}');
    }
  }
}
