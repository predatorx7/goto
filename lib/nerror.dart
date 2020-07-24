import 'dart:io' show exit;
import 'package:colorize/colorize.dart';

class GotoError {
  GotoError([String reason]) {
    Colorize err = Colorize('[Goto] $reason');
    err.apply(Styles.YELLOW);
    err.italic();
    print(err);
    exit(1);
  }
  GotoError.missing([String usage = '']) {
    Colorize missing = Colorize("ERROR: Arguments missing ");
    missing.apply(Styles.LIGHT_RED);
    print('$usage\n\n$missing');
    exit(1);
  }
  GotoError.exit(String message) {
    Colorize exitmsg = Colorize(message);
    exitmsg.apply(Styles.LIGHT_RED);
    print(exitmsg);
    exit(1);
  }
  GotoError.warn([String reason]) {
    Colorize err = Colorize(reason);
    err.apply(Styles.YELLOW);
    err.italic();
    print(err);
    exit(1);
  }
}
