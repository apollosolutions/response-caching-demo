#!/usr/bin/env bash
# Runs every scenario in order and prints a summary. Takes ~2.5 minutes
# because some scenarios wait for TTLs to expire.
set -u
cd "$(dirname "$0")/../scenarios"

failed=()
for dir in */; do
  dir="${dir%/}"
  [ -x "$dir/run.sh" ] || continue
  if ! "./$dir/run.sh"; then
    failed+=("$dir")
  fi
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "✅ All scenarios passed."
else
  echo "❌ Failed scenarios: ${failed[*]}"
  exit 1
fi
