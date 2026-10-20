#!/bin/bash
# Copies the Map Editor line script (vana-lib/lib/edf_lines_client.lua) into the resources whose EDFs
# load it: the editor runs EDF scripts from the defining resource's own folder. Everything else in
# vana-lib is imported at runtime instead (docs/libraries.md). tools/lint.sh fails if a copy differs.
# Usage: tools/sync-libs.sh [--check]
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/vana-lib/lib/edf_lines_client.lua"
status=0
for copy in vana-interiors/edf/edf_lines_client.lua vana-activities/edf/edf_lines_client.lua vana-encounters/edf/edf_lines_client.lua; do
    if [[ "${1:-}" == "--check" ]]; then
        cmp -s "$SRC" "$ROOT/$copy" || { echo "out of sync: $copy (run tools/sync-libs.sh)"; status=1; }
    else
        cp "$SRC" "$ROOT/$copy"
    fi
done
exit $status
