import 'dart:io';

void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final repoRoot = scriptDir.parent;

  final appsDir = Directory('${repoRoot.path}/apps');
  if (!appsDir.existsSync()) {
    print('❌ apps directory not found at ${appsDir.path}');
    exit(1);
  }

  // Find app_router.dart
  final matches = appsDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith(
            '${Platform.pathSeparator}lib${Platform.pathSeparator}router${Platform.pathSeparator}app_router.dart',
          ))
      .toList();

  if (matches.isEmpty) {
    print('❌ app_router.dart not found under apps/');
    exit(1);
  }

  if (matches.length > 1) {
    print('⚠ Multiple app_router.dart files found:');
    for (final f in matches) print(' - ${f.path}');
    exit(1);
  }

  final file = matches.first;
  print('✅ Found app_router.dart at:\n${file.path}\n');

  String content = file.readAsStringSync();
  bool languageRouteCommented = false;
  bool loginRouteUpdated = false;

  // ------------------ COMMENT ONLY LanguageSelectionRoute ------------------
  content = content.replaceAllMapped(
    RegExp(
      r'AutoRoute\(\s*\n\s*page:\s*LanguageSelectionRoute\.page[\s\S]*?\),',
      multiLine: true,
    ),
    (match) {
      languageRouteCommented = true;
      return match.group(0)!.split('\n').map((line) => '// $line').join('\n');
    },
  );

  // ------------------ MAKE LoginRoute initial (single-line or multi-line) ------------------
  content = content.replaceAllMapped(
    RegExp(
      r'AutoRoute\(\s*page:\s*LoginRoute\.page[\s\S]*?\),',
      multiLine: true,
    ),
    (match) {
      final block = match.group(0)!;
      if (block.contains('initial:')) return block;

      loginRouteUpdated = true;

      // Insert initial: true before closing
      if (block.contains('\n')) {
        // multi-line
        return block.replaceFirst(RegExp(r'\)\s*,'), ',\n  initial: true,\n),');
      } else {
        // single-line
        return block.replaceFirst(RegExp(r'\),'), ', initial: true),');
      }
    },
  );

  file.writeAsStringSync(content);

  print('✅ Update completed\n');
  print(languageRouteCommented
      ? '✔ LanguageSelectionRoute commented'
      : '⚠ LanguageSelectionRoute not found');
  print(loginRouteUpdated
      ? '✔ LoginRoute set as initial'
      : '⚠ LoginRoute already initial or not found');
}
