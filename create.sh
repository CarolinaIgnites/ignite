#!/usr/bin/env bash

unlock() {
    local listing=".nodes.root.inputs.\\\"$inputs\\\""
    local input=".nodes.\\\"$inputs\\\""
    local compressed=$(jq -c "\"del($input) | del($listing)\"" flake.lock)
    test -f flake.lock && echo "$compressed" | jq > flake.lock
}

[ -f flake.lock ] && unlock ignite-api ignite-editor
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

nixos-container destroy ignite
nixos-container create ignite --override-input ignite-api `pwd`/igniteApi --override-input ignite-editor `pwd`/editFrame --flake .

nixos-container start ignite
