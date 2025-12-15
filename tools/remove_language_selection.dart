import 'dart:io';

void main() {
  // ------------------ LOCATE app_router.dart ------------------
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final repoRoot = scriptDir.parent;

  final appsDir = Directory('${repoRoot.path}/apps');

  if (!appsDir.existsSync()) {
    print('❌ apps/ directory not found at ${appsDir.path}');
    exit(1);
  }

  // Find app_router.dart under apps/**/lib/router/
  final matches = appsDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith(
            '${Platform.pathSeparator}lib'
            '${Platform.pathSeparator}router'
            '${Platform.pathSeparator}app_router.dart',
          ))
      .toList();

  if (matches.isEmpty) {
    print('❌ app_router.dart not found under apps/');
    exit(1);
  }

  if (matches.length > 1) {
    print('⚠ Multiple app_router.dart files found:');
    for (final f in matches) {
      print(' - ${f.path}');
    }
    print('Please narrow the search.');
    exit(1);
  }

  final file = matches.first;
  print('✅ Found app_router.dart at:\n${file.path}\n');

  // ------------------ READ FILE ------------------
  String content = file.readAsStringSync();

  bool languageRouteCommented = false;
  bool loginRouteUpdated = false;

  // ------------------ 1️⃣ COMMENT ONLY LanguageSelectionRoute ------------------
  content = content.replaceAllMapped(
    RegExp(
      r'''AutoRoute\(\s*
page:\s*LanguageSelectionRoute\.page,\s*
path:\s*['"]language_selection['"],\s*
initial:\s*true,\s*
\),''',
      multiLine: true,
    ),
    (match) {
      languageRouteCommented = true;

      final commentedLines =
          match.group(0)!.split('\n').map((line) => '// $line').toList();

      return commentedLines.join('\n');
    },
  );

  // ------------------ 2️⃣ MAKE LoginRoute initial ------------------
  content = content.replaceAllMapped(
    RegExp(
      r'AutoRoute\(\s*'
      r'page:\s*LoginRoute\.page,'
      r'[\s\S]*?\),',
      multiLine: true,
    ),
    (match) {
      final block = match.group(0)!;

      // Skip if already initial
      if (block.contains('initial:')) {
        return block;
      }

      loginRouteUpdated = true;

      // Insert initial: true before closing
      return block.replaceFirst(
        RegExp(r'\)\s*,'),
        ',\n  initial: true,\n),',
      );
    },
  );

  // ------------------ WRITE FILE ------------------
  file.writeAsStringSync(content);

  // ------------------ RESULT ------------------
  print('✅ Update completed');
  print(languageRouteCommented
      ? '✔ LanguageSelectionRoute commented out'
      : '⚠ LanguageSelectionRoute not found');

  print(loginRouteUpdated
      ? '✔ LoginRoute set as initial'
      : '⚠ LoginRoute already initial or not found');
}
