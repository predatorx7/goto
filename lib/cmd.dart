import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:goto/goto.dart';
import 'package:goto/nerror.dart';

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
    Goto().gotoPath(key);
  }
}

/// Saves a path with key
class SetCommand extends Command<String> {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "set";
  @override
  final description = "Saves a path with a key.";

  SetCommand();

  @override
  String get invocation => 'goto set <key> <path>';

  @override
  List<String> get aliases => ['save', 's'];

  final RegExp keyRegx = RegExp(r'^\w*$');

  // [run] may also return a Future.
  @override
  Future<String> run() {
    if (argResults.rest?.isEmpty ?? true) {
      GotoError.missing(usage);
    }
    String key = argResults.rest[0];
    if (!keyRegx.hasMatch(key)) {
      GotoError(
          "Key invalid. Key must only contain alphabet, underscore, or numbers");
    }
    String value = (argResults.rest.length == 1)
        ? Directory.current.path
        : argResults.rest[1];
    if (value == '.') {
      value = Directory.current.path;
    }
    print('Saving $value with key $key.. ');
    Goto().setKey(key, value);
  }
}

/// Retrieves and prints a path for a key
class GetCommand extends Command<String> {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "get";
  @override
  final description = "Gets a path address matching the key";

  GetCommand();

  @override
  String get invocation => 'goto get <key>';

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
    String reply = Goto().getPath(key);
    if (reply == null) {
      GotoError('Found no path with "$key" key');
    }
    print('$key -> ${reply}');
  }
}

/// Remove a saved key-path or remove all saved key-paths
class RemoveCommand extends Command<String> {
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
  String get invocation => 'goto remove <key>';

  @override
  List<String> get aliases => ['rm', 'r'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    if (argResults['all']) {
      // remove all
      Goto().removeAll();
      return null;
    }
    if (argResults.rest?.isEmpty ?? true) {
      GotoError.missing(usage);
    }
    // [argResults] is set before [run()] is called and contains the options
    // passed to this command.
    Goto().removeKey(argResults.rest[0]);
  }
}

/// Lists all saved key-path pairs in human readable format
class ListCommand extends Command<String> {
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
  String get invocation => 'goto list';

  @override
  List<String> get aliases => ['ls', 'l'];

  // [run] may also return a Future.
  @override
  Future<String> run() {
    Map data = Goto().data;
    if (data.isEmpty) {
      print('No saved records');
      return null;
    }
    for (var item in data.keys) {
      print('$item: ${data[item]}');
    }
  }
}
