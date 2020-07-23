import 'package:args/command_runner.dart';
import 'package:goto/cmd.dart';

void main(List<String> arguments) {
  final CommandRunner gotoCommand = CommandRunner<String>('goto',
      'Goto keeps a key-value record of paths you wish to save for quick access later.\n\nUse "goto <key>" to redirect to <key>\'s path')
    ..addCommand(SetCommand())
    ..addCommand(GetCommand())
    ..addCommand(ListCommand())
    ..addCommand(RemoveCommand());
  var res = gotoCommand.parse(arguments);
  if (res.command == null && arguments.length == 1) {
    GoCommand(arguments, gotoCommand).run();
  } else {
    gotoCommand.run(arguments);
  }
}
