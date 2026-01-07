import 'dart:io';

Future<void> runCommand(String command, String workingDir) async {
  final dir = Directory(workingDir);
  if (!await dir.exists()) {
    print('❌ Directory does not exist: $workingDir');
    exit(1);
  }

  print('▶ Running: $command');
  print('📂 In directory: $workingDir');

  try {
    final result = await Process.run(
      Platform.isWindows ? 'cmd.exe' : 'bash',
      Platform.isWindows ? ['/c', command] : ['-c', command],
      workingDirectory: workingDir,
    );

    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      print('❌ Command failed with exit code ${result.exitCode}');
      exit(result.exitCode);
    }
  } catch (e) {
    print('❌ Error running command: $e');
    exit(1);
  }
}

void main() async {
  // Use current working directory as repo root
  final repoRoot = Directory.current.path;

  final healthAppPath = '$repoRoot/apps/health_campaign_field_worker_app';
  final toolsPath = '$repoRoot/tools';

  print('===========================================');
  print('    HEALTH PROJECT SETUP RUNNING…');
  print('===========================================');

  // Step 1: Run install_bricks.sh in tools folder
  await runCommand('bash install_bricks.sh', toolsPath);

  // Step 2: Flutter pub get in health app folder
  await runCommand('flutter pub get', healthAppPath);

  // Step 3: Flutter clean in health app folder
  await runCommand('flutter clean', healthAppPath);

  // Step 4: Build runner in tools folder
  await runCommand(
      'flutter packages pub run build_runner build --delete-conflicting-outputs',
      toolsPath);

  print('✅ HEALTH PROJECT SETUP COMPLETED');
}
