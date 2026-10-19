#!/bin/bash
# Copies the shared libraries in tools/lib into the resources that use them (MTA loads scripts only
# from inside a resource). tools/lint.sh fails if a copy differs from its source.
# Usage: tools/sync-libs.sh [--check]
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# source (tools/lib/...) -> copies (relative to the repo root)
COPIES=(
    "map_data.lua:vana-player/map_data.lua vana-parked/map_data.lua vana-interiors/map_data.lua vana-shops/map_data.lua vana-gym/map_data.lua vana-activities/core/map_data.lua vana-wildlife/map_data.lua"
    "edf_lines_client.lua:vana-interiors/edf/edf_lines_client.lua vana-activities/edf/edf_lines_client.lua vana-wildlife/edf/edf_lines_client.lua"
    "map_points.lua:vana-map/provider.lua vana-interiors/map_points.lua vana-activities/core/map_points.lua"
    "sa_reader.lua:vana-shops/sa_reader.lua vana-activities/core/sa_reader.lua vana-population/sa_reader.lua vana-vehicles/sa_reader.lua"
    "sa_txd.lua:vana-vehicles/sa_txd.lua"
    "sa_gxt.lua:vana-shops/sa_gxt.lua vana-activities/core/sa_gxt.lua"
    "sa_ide.lua:vana-population/sa_ide.lua"
    "sa_dat.lua:vana-population/sa_dat.lua vana-shops/sa_dat.lua"
)
status=0
for entry in "${COPIES[@]}"; do
    src="$HERE/lib/${entry%%:*}"
    for copy in ${entry#*:}; do
        if [[ "${1:-}" == "--check" ]]; then
            cmp -s "$src" "$ROOT/$copy" || { echo "out of sync: $copy (run tools/sync-libs.sh)"; status=1; }
        else
            mkdir -p "$(dirname "$ROOT/$copy")"
            cp "$src" "$ROOT/$copy"
        fi
    done
done
exit $status
