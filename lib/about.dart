import 'dart:io';

const String _about = """Goto v0.0.5

Copyright (c) 2020, Syed Mushaheed. All rights reserved.
Licensed with BSD 3-Clause License.

Written by Mushaheed Syed <smushaheed@gmail.com>""";

/// Callback to show version information if -V or --version flag is used
void version(bool called) {
  if (!called) return;
  print(_about);
  exit(0);
}
