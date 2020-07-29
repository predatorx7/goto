import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:goto/about.dart';
import 'package:goto/cmd.dart';
import 'package:goto/nerror.dart';

void main(List<String> arguments) {
  ArgResults res;

  // goto cli's command runner interface
  final CommandRunner<String> gotoCommand = CommandRunner<String>('goto',
      'Goto keeps a key-value record of paths you wish to save for quick access later.\n\nUse "goto <key>" to redirect to <key>\'s path')
    // Add commands to the cli
    ..addCommand(GetCommand())
    ..addCommand(ListCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(RenameCommand())
    ..addCommand(SetCommand())
    // Add about-version details to cli
    ..argParser.addFlag('version',
        abbr: 'V',
        help: 'Output version information and exit',
        callback: version);

  try {
    // Parse commands, options & flags
    res = gotoCommand.parse(arguments);
  } on UsageException catch (e) {
    // Shows clean error on wrong usage
    GotoError.exit(e.toString());
  }

  if (res.command == null && arguments.length == 1) {
    // if no command is found then this might be a help flag or a go command
    if (res.arguments.first == '-h' || res.arguments.first == '--help') {
      // To avoid callback issue in command runner. this flag is separately
      // handled here.
      gotoCommand.printUsage();
    } else {
      // If this isn't a help flag, then it's a go command
      // GoCommand only requires key name
      GoCommand(arguments, gotoCommand).run();
    }
  } else {
    // Arguments have a command.
    // CommandRunner.run executes the appropriate command from argument.
    gotoCommand.run(arguments).catchError((e) {
      // show error on future usage error
      GotoError.exit(e.toString());
    });
  }
}
