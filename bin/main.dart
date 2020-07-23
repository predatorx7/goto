import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:goto/cmd.dart';
import 'package:goto/nerror.dart';

void main(List<String> arguments) {
  final CommandRunner gotoCommand = CommandRunner<String>('goto',
      'Goto keeps a key-value record of paths you wish to save for quick access later.\n\nUse "goto <key>" to redirect to <key>\'s path')
    ..addCommand(SetCommand())
    ..addCommand(GetCommand())
    ..addCommand(ListCommand())
    ..addCommand(RemoveCommand());
  ArgResults res;
  try {
    res = gotoCommand.parse(arguments);
  } on UsageException catch (e) {
    GotoError.exit(e.toString());
  }
  if (res.command == null && arguments.length == 1) {
    GoCommand(arguments, gotoCommand).run();
  } else {
    gotoCommand.run(arguments).catchError((e) {
      GotoError.exit(e.toString());
    });
  }
}
