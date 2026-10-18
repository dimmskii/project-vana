#!/bin/bash
# Lints every resource (or the ones named): luac5.1 syntax, then luacheck with MTA's client or server
# globals (tools/luacheck/mta-*.txt: the pinned Neon API stubs plus the functions its luadefs register) plus each resource's own
# globals (anything a file of it assigns at top level). Needs lua5.1 and lua-check (docs/setup.md).
# Usage: tools/lint.sh [resource ...]
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
EVENT_VARS="source client root resourceRoot localPlayer resource sourceResource sourceResourceRoot exports eventName this guiRoot sourceTimer"
status=0
cd "$ROOT"
resources=("$@")
[[ ${#resources[@]} -eq 0 ]] && resources=($(ls -d vana-*/ | tr -d /))
for res in "${resources[@]}"; do
    mapfile -d '' files < <(find "$res" -name '*.lua' -print0)
    for f in "${files[@]}"; do luac5.1 -p "$f" || status=1; done
    # The resource's own globals: top-level assignments in any of its files.
    own=$(for f in "${files[@]}"; do luac5.1 -p -l "$f" 2>/dev/null | awk '/SETGLOBAL/ {print $NF}'; done | sort -u | tr '\n' ' ')
    for f in "${files[@]}"; do
        # Client, server or shared, as the resource's meta.xml loads it (server if it isn't listed).
        type=$(grep -oE "<script[^>]*src=\"${f#$res/}\"[^>]*>" "$res/meta.xml" | grep -oE 'type="[a-z]+"' | head -1 | cut -d'"' -f2)
        case "$type" in
            client) mta=$(tr '\n' ' ' < "$HERE/luacheck/mta-client.txt") ;;
            shared) mta=$(cat "$HERE"/luacheck/mta-*.txt | sort -u | tr '\n' ' ') ;;
            *) mta=$(tr '\n' ' ' < "$HERE/luacheck/mta-server.txt") ;;
        esac
        out=$(luacheck --std lua51 --no-max-line-length --no-unused-args --no-self --codes \
            --read-globals $mta $EVENT_VARS --globals $own -- "$f" 2>&1)
        if [[ $? -ne 0 ]]; then echo "$out" | grep -E '^\s+\S+:[0-9]+:[0-9]+' ; status=1; fi
    done
done
exit $status
