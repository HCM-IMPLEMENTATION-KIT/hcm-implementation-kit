import 'dart:io';

class ScriptTask {
  final String name;
  final String path;

  ScriptTask(this.name, this.path);
}

Future<void> runScript(ScriptTask task) async {
  print('\n▶ Running: ${task.name}');

  late String executable;
  late List<String> arguments;

  if (task.path.endsWith('.dart')) {
    executable = 'dart';
    arguments = [task.path];
  } else if (task.path.endsWith('.sh')) {
    executable = 'bash';
    arguments = [task.path];
  } else {
    throw UnsupportedError(
      'Unsupported script type: ${task.path}',
    );
  }

  print('   $executable ${arguments.join(' ')}\n');

  // IMPORTANT: inheritStdio enables interactive input
  final process = await Process.start(
    executable,
    arguments,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    print('\n❌ FAILED: ${task.name}');
    exit(exitCode);
  }

  print('✅ SUCCESS: ${task.name}');
}

Future<void> main() async {
  final tasks = <ScriptTask>[
    ScriptTask(
      'Create Environment Files',
      'tools/create_env_overrides.dart',
    ),
    ScriptTask(
      'Update App Router',
      'tools/remove_language_selection.dart',
    ),
    ScriptTask(
      'Packages setup',
      'tools/init_implementation.sh',
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
