#!/bin/sh

set -eu
set -f

# TODO: pipefail

export IFS=' '

# DRV_PATH and OUT_PATHS
# DRV_PATH=/nix/store/4hhj43gzgvzarwc1jl5kgj7dq31mx1zv-example.drv
# OUT_PATHS="/nix/store/bfqvkn7yp29dpsbp7hssmvllmd2gin7x-example-bin /nix/store/c07lm8hpqamcxnyzyc541p1f62325s2p-example /nix/store/gpbijimi8kdn4afjd62la158pbhb0iq4-example-lib"

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

# We add both narHash (which in-toto does not define) and sha256 (which in-toto does define)
# the sha256 is over the nar-serialization. So people should do `nix store dump-path` as file to verify instead of a directory

subjects=$(for path in $OUT_PATHS; do
    subject=$("$nix" path-info "$path" --json | jq --arg path "$path" '.[$path]| {name:$path, digest:{narHash:.narHash}, annotations:.}')
    narHash=$(echo "$subject" | jq -r '.digest.narHash')
    sha256="sha256:$(nix hash convert --to base16 "$narHash")"
    echo "$subject" | jq --arg sha256 "$sha256" '.digest.sha256=$sha256'
done  | jq -s .)
derivation=$("$nix" derivation show "$DRV_PATH" | jq --arg DRV_PATH "$DRV_PATH" '.[$DRV_PATH]')
inputDrvs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputDrvs | to_entries | map(.key as $key | .value.outputs[]|"\($key)^\(.)")[]')
inputSrcs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputSrcs[]')
#resolvedInputs=$({ echo "$inputDrvs" ; echo "$inputSrcs"; } | xargs "$nix" path-info --json | jq 'to_entries')

resolvedDependencies=$(echo "$inputDrvs" | while IFS= read -r path; do
    dep=$("$nix" path-info "$path" --json | jq 'to_entries | map({name:.key, digest:{narHash:.value.narHash}, annotations:.value})[]')
    narHash=$(echo "$dep" | jq -r '.digest.narHash')
    sha256="sha256:$(nix hash convert --to base16 "$narHash")"
    echo "$dep" | jq --arg sha256 "$sha256" '.digest.sha256=$sha256'
done | jq -s .)

mkdir -p /nix/var/nix/provenance/nix/store

jq -n \
    --argjson derivation "$derivation" \
    --argjson resolvedDependencies "$resolvedDependencies" \
    --argjson subject "$subjects" \
    '{
        "_type": "https://in-toto.io/Statement/v1",
        "subject": $subject,
        "predicate": {
            "buildType": "https//nixos.org/slsa/v1",
            "externalParameters": {
                "derivation":  $derivation,
            },
            "internalParameters": {},
            "resolvedDependencies": $resolvedDependencies
        }
    }' > "/nix/var/nix/provenance$DRV_PATH.slsa.json"

