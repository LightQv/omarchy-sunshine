#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if ! command -v quickshell >/dev/null 2>&1; then
  printf '%s\n' "Quickshell is required for the service smoke tests." >&2
  exit 1
fi

test_root=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-sunshine-service.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

run_case() {
  local name=$1
  local harness=$2
  local marker=$3
  local start_delay=$4
  local case_root="$test_root/$name"
  local output
  local status

  mkdir -p -- "$case_root/bin" "$case_root/fake-systemctl" \
    "$case_root/home/.config/sunshine"
  cp -- "$repo_root/tests/qml/$harness" "$case_root/shell.qml"
  cp -a -- "$repo_root" "$case_root/Plugin"
  cp -- "$repo_root/tests/helpers/fake-systemctl" "$case_root/bin/systemctl"
  chmod +x -- "$case_root/bin/systemctl"
  printf '%s\n' 'port = 49000' >"$case_root/home/.config/sunshine/sunshine.conf"

  set +e
  output=$(HOME="$case_root/home" \
    FAKE_SYSTEMCTL_COMMAND="$case_root/bin/systemctl" \
    FAKE_SYSTEMCTL_ROOT="$case_root/fake-systemctl" \
    FAKE_SYSTEMCTL_START_DELAY="$start_delay" \
    timeout 7s quickshell --no-color --path "$case_root/shell.qml" 2>&1)
  status=$?
  set -e

  if (( status != 0 )) || [[ $output != *"$marker"* ]]; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  if [[ -e $case_root/fake-systemctl/concurrent ]]; then
    printf '%s\n' "Concurrent systemctl commands detected in $name." >&2
    return 1
  fi
}

run_case queue ServiceQueueSmoke.qml SERVICE_QUEUE_SMOKE_OK 0.2

mapfile -t queue_calls <"$test_root/queue/fake-systemctl/calls"
expected_queue_calls=(
  "--user show app-dev.lizardbyte.app.Sunshine.service --property=LoadState --property=ActiveState --property=SubState --property=UnitFileState"
  "--user start app-dev.lizardbyte.app.Sunshine.service"
  "--user show app-dev.lizardbyte.app.Sunshine.service --property=LoadState --property=ActiveState --property=SubState --property=UnitFileState"
  "--user disable app-dev.lizardbyte.app.Sunshine.service"
  "--user show app-dev.lizardbyte.app.Sunshine.service --property=LoadState --property=ActiveState --property=SubState --property=UnitFileState"
)
if (( ${#queue_calls[@]} != ${#expected_queue_calls[@]} )); then
  printf 'Unexpected queue command count: %s\n' "${queue_calls[*]}" >&2
  exit 1
fi
for index in "${!expected_queue_calls[@]}"; do
  if [[ ${queue_calls[index]} != "${expected_queue_calls[index]}" ]]; then
    printf 'Unexpected queue command %d: %s\n' "$index" "${queue_calls[index]}" >&2
    exit 1
  fi
done

run_case timeout ServiceTimeoutSmoke.qml SERVICE_TIMEOUT_SMOKE_OK 30
mapfile -t timeout_calls <"$test_root/timeout/fake-systemctl/calls"
if (( ${#timeout_calls[@]} != 3 )) \
    || [[ ${timeout_calls[0]} != "${expected_queue_calls[0]}" ]] \
    || [[ ${timeout_calls[1]} != "--user start app-dev.lizardbyte.app.Sunshine.service" ]] \
    || [[ ${timeout_calls[2]} != "${expected_queue_calls[0]}" ]]; then
  printf 'Unexpected timeout commands: %s\n' "${timeout_calls[*]}" >&2
  exit 1
fi

printf '%s\n' "Service status, queue, failure, and timeout smoke tests passed."
