import 'dart:io' show exit;

class GotoError {
  GotoError.missing() {
    print('ERROR: Arguments missing\n');
  }
  GotoError([String reason]) {
    print('Error: $reason');
    exit(1);
  }
}
