#!/bin/bash

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEALTH_APP_PATH="$REPO_ROOT/apps/health_campaign_field_worker_app"
TOOLS_PATH="$REPO_ROOT/tools"

run_command() {
  local command="$1"
  local working_dir="$2"

  if [ ! -d "$working_dir" ]; then
    echo "❌ Directory does not exist: $working_dir"
    exit 1
  fi

  echo "▶ Running: $command"
  echo "📂 In directory: $working_dir"

  (cd "$working_dir" && eval "$command") || {
    echo "❌ Command failed: $command"
    exit 1
  }
}

# Like run_command but prints a warning and continues on failure
run_command_warn() {
  local command="$1"
  local working_dir="$2"

  if [ ! -d "$working_dir" ]; then
    echo "❌ Directory does not exist: $working_dir"
    exit 1
  fi

  echo "▶ Running: $command"
  echo "📂 In directory: $working_dir"

  (cd "$working_dir" && eval "$command") || {
    echo "⚠️  Command failed (continuing): $command"
  }
}

echo "==========================================="
echo "    HEALTH PROJECT SETUP RUNNING…"
echo "==========================================="

# Step 1: Run install_bricks.sh in tools folder (non-fatal — continue on failure)
run_command_warn "bash install_bricks.sh" "$TOOLS_PATH"

# Step 2: Flutter pub get in health app folder
run_command "fvm flutter pub get" "$HEALTH_APP_PATH"

# Step 3: Flutter clean in health app folder
run_command "fvm flutter clean" "$HEALTH_APP_PATH"

# Step 4: Build runner in tools folder
run_command "fvm dart run build_runner build --delete-conflicting-outputs" "$HEALTH_APP_PATH"

echo "✅ HEALTH PROJECT SETUP COMPLETED"
