#!/bin/sh

set -eu
set -f
export IFS=' '

# DRV_PATH and OUT_PATHS
#DRV_PATH=/nix/store/4hhj43gzgvzarwc1jl5kgj7dq31mx1zv-example.drv
#OUT_PATHS="/nix/store/bfqvkn7yp29dpsbp7hssmvllmd2gin7x-example-bin /nix/store/c07lm8hpqamcxnyzyc541p1f62325s2p-example /nix/store/gpbijimi8kdn4afjd62la158pbhb0iq4-example-lib"

if [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    nix=/nix/var/nix/profiles/default/bin/nix
elif [ -x /run/current-system/sw/bin/nix ]; then
    nix=/run/current-system/sw/bin/nix 
else
    echo "nix binary not found"
    exit 1
fi

# TODO: package this hook as a package
jq() {
    "$nix" run nixpkgs/nixos-24.11#jq -- "$@"
}

# TODO: What to do with narHash? do we want to do sha256: here and use the NAR file?
subject=$("$nix" path-info $OUT_PATHS --json | jq 'to_entries|map({name:.key,digest:{narHash:.value.narHash}, annotations:.value})')
derivation=$("$nix" derivation show "$DRV_PATH" | jq --arg DRV_PATH "$DRV_PATH" '.[$DRV_PATH]')
inputDrvs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputDrvs | to_entries | map(.key as $key | .value.outputs[]|"\($key)^\(.)")[]')
inputSrcs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputSrcs[]')

resolvedInputs=$({ echo "$inputDrvs" ; echo "$inputSrcs"; } | xargs "$nix" path-info --json | jq '.')

mkdir -p /nix/var/nix/provenance/nix/store

jq -n \
    --argjson derivation "$derivation" \
    --argjson resolvedInputs "$resolvedInputs" \
    --argjson subject "$subject" \
    '{
        "_type": "https://in-toto.io/Statement/v1",
        "subject": $subject,
        "predicate": {
            "buildType": "https//nixos.org/slsa/v1",
            "externalParameters": {
                "derivation":  $derivation,
            },
            "internalParameters": {},
            "resolvedDependencies": $resolvedInputs | map({name:.path,digest:{narHash:.narHash}, annotations:.}),
        }
    }' > "/nix/var/nix/provenance$DRV_PATH.slsa.json"

