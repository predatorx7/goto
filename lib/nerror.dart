import 'dart:io' show exit;

class GotoError {
  GotoError.missing([String usage = '']) {
    print('ERROR: Arguments missing\n\n$usage');
    exit(1);
  }
  GotoError.exit(String message) {
    print(message);
    exit(1);
  }
  GotoError([String reason]) {
    print('Error: $reason');
    exit(1);
  }
}
