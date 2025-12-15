import 'dart:io';

void main() {
  // Script location: hcm-implementation-kit/tools/
  final scriptDir = File(Platform.script.toFilePath()).parent;

  // Project root: hcm-implementation-kit/
  final projectRoot = scriptDir.parent.path;

  print('Resolved project root: $projectRoot');

  final targetPath = '$projectRoot/apps/health_campaign_field_worker_app';
  final outputDir = Directory(targetPath);

  if (!outputDir.existsSync()) {
    print('❌ ERROR: Target directory does not exist:\n$targetPath');
    exit(1);
  }

  final files = <String, String>{
    '.env': '''
# ================================================
# LOCAL ENVIRONMENT VARIABLES
# ================================================
BASE_URL="https://dev.example.com/"
MDMS_API_PATH="mdms-v2/v1/_search"
TENANT_ID="ng"
ACTIONS_API_PATH="access/v1/actions/mdms/_get"
SYNC_DOWN_RETRY_COUNT="3"
RETRY_TIME_INTERVAL="5"
CONNECT_TIMEOUT="120000"
RECEIVE_TIMEOUT="120000"
SEND_TIMEOUT="120000"
CHECK_BANDWIDTH_API="/project/check/bandwidth"
HIERARCHY_TYPE="ADMIN"
ENV_NAME="DEV"
''',
    '.env-qa': '''
# ================================================
# QA ENVIRONMENT VARIABLES
# ================================================
BASE_URL="https://qa.example.com/"
MDMS_API_PATH="mdms-v2/v1/_search"
TENANT_ID="ng"
ACTIONS_API_PATH="access/v1/actions/mdms/_get"
SYNC_DOWN_RETRY_COUNT="3"
RETRY_TIME_INTERVAL="5"
CONNECT_TIMEOUT="120000"
RECEIVE_TIMEOUT="120000"
SEND_TIMEOUT="120000"
CHECK_BANDWIDTH_API="/project/check/bandwidth"
HIERARCHY_TYPE="ADMIN"
ENV_NAME="QA"
''',
    '.env-prod': '''
# ================================================
# PRODUCTION ENVIRONMENT VARIABLES
# ================================================
BASE_URL="https://prod.hcm-kano.org/"
MDMS_API_PATH="mdms-v2/v1/_search"
TENANT_ID="ng"
ACTIONS_API_PATH="access/v1/actions/mdms/_get"
SYNC_DOWN_RETRY_COUNT="3"
RETRY_TIME_INTERVAL="5"
CONNECT_TIMEOUT="120000"
RECEIVE_TIMEOUT="120000"
SEND_TIMEOUT="120000"
CHECK_BANDWIDTH_API="/project/check/bandwidth"
HIERARCHY_TYPE="ADMIN"
ENV_NAME="PROD"
''',
    'pubspec_overrides.yaml': '''
# ================================================
# Dependency Overrides (for local development only)
# ================================================
# Auto-generated — do not commit to Git.
''',
  };

  print('🔧 Creating environment files at:\n$targetPath\n');

  files.forEach((fileName, content) {
    final file = File('$targetPath/$fileName');

    if (file.existsSync()) {
      print('⚠️ Skipped (already exists): $fileName');
    } else {
      file.writeAsStringSync(content.trimLeft());
      print('✅ Created: ${file.path}');
    }
  });

  print('\n🎉 Environment setup completed successfully!');
}
