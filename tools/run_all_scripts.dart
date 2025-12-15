import 'dart:io';

class ScriptTask {
  final String name;
  final String path;

  ScriptTask(this.name, this.path);
}

Future<void> runScript(ScriptTask task) async {
  print('\n▶ Running: ${task.name}');
  print('   dart ${task.path}\n');

  final result = await Process.run(
    'dart',
    [task.path],
    runInShell: true,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    print('\n❌ FAILED: ${task.name}');
    exit(result.exitCode);
  }

  print('✅ SUCCESS: ${task.name}');
}

Future<void> main() async {
  final tasks = [
    ScriptTask(
      'Create Environment Files',
      'tools/create_env_overrides.dart',
    ),
    ScriptTask(
      'Update App Router',
      'tools/remove_language_selection.dart',
    ),
    ScriptTask(
      'Health App Setup',
      'tools/run_initial_setup_commands.dart',
    ),
  ];

  print('\n🚀 RUNNING ALL SETUP SCRIPTS\n');

  for (final task in tasks) {
    await runScript(task);
  }

  print('\n🎉 ALL SCRIPTS COMPLETED SUCCESSFULLY\n');
}
