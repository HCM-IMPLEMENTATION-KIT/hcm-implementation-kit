import 'dart:io';

Future<void> runCommand(String command, String workingDir,
    {bool exitOnError = true}) async {
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
      if (exitOnError) {
        print('❌ Command failed with exit code ${result.exitCode}');
        exit(result.exitCode);
      } else {
        print('⚠️  Command failed (continuing): $command');
      }
    }
  } catch (e) {
    if (exitOnError) {
      print('❌ Error running command: $e');
      exit(1);
    } else {
      print('⚠️  Error running command (continuing): $e');
    }
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

  // Step 1: Run install_bricks.sh in tools folder (non-fatal — continue on failure)
  await runCommand('bash install_bricks.sh', toolsPath, exitOnError: false);

  // Use fvm if available, otherwise fall back to plain flutter/dart
  final fvmCheck = await Process.run('which', ['fvm']);
  final fvm = fvmCheck.exitCode == 0 ? 'fvm ' : '';
  print(fvm.isNotEmpty
      ? 'ℹ️  fvm detected — using fvm'
      : 'ℹ️  fvm not found — using system flutter/dart');

  // Step 2: Flutter pub get in health app folder
  await runCommand('${fvm}flutter pub get', healthAppPath);

  // Step 3: Flutter clean in health app folder
  await runCommand('${fvm}flutter clean', healthAppPath);

  // Step 4: Build runner in health app folder
  await runCommand(
      '${fvm}dart run build_runner build --delete-conflicting-outputs',
      healthAppPath);

  print('✅ HEALTH PROJECT SETUP COMPLETED');
}
