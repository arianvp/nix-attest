{
  writeShellApplication,
  jq,
  nix,
}:
writeShellApplication {
  name = "nix-attest-post-build-hook";
  runtimeInputs = [
    jq
    nix
  ];
  text = ''
    export IFS=' '
    env

    # DRV_PATH and OUT_PATHS
    # DRV_PATH=/nix/store/4hhj43gzgvzarwc1jl5kgj7dq31mx1zv-example.drv
    # OUT_PATHS="/nix/store/bfqvkn7yp29dpsbp7hssmvllmd2gin7x-example-bin /nix/store/c07lm8hpqamcxnyzyc541p1f62325s2p-example /nix/store/gpbijimi8kdn4afjd62la158pbhb0iq4-example-lib"


    # We add both narHash (which in-toto does not define) and sha256 (which in-toto does define)
    # the sha256 is over the nar-serialization. So people should do `nix store dump-path` as file to verify instead of a directory

    subjects=$(for path in $OUT_PATHS; do
        subject=$(nix path-info "$path" --json | jq --arg path "$path" '.[$path]| {name:$path, digest:{narHash:.narHash}, annotations:.}')
        narHash=$(echo "$subject" | jq -r '.digest.narHash')
        sha256="$(nix hash convert --to base16 "$narHash")"
        echo "$subject" | jq --arg sha256 "$sha256" '.digest.sha256=$sha256'
    done  | jq -s .)
    derivation=$(nix derivation show "$DRV_PATH" | jq --arg DRV_PATH "$DRV_PATH" '.[$DRV_PATH]')
    inputDrvs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputDrvs | to_entries | map(.key as $key | .value.outputs[]|"\($key)^\(.)")[]')
    inputSrcs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputSrcs[]')

    resolvedDependencies=$({ echo "$inputDrvs"; echo "$inputSrcs"; } | while IFS= read -r path; do
        dep=$(nix path-info "$path" --json | jq 'to_entries | map({name:.key, digest:{narHash:.value.narHash}, annotations:.value})[]')
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
            "predicateType": "https://nixos.org/provenance/v1",
            "predicate": {
                "buildDefinition": {
                    "buildType": "https://nixos.org/build/v1",
                    "externalParameters": {
                        "derivation":  $derivation
                    },
                    "internalParameters": {},
                    "resolvedDependencies": $resolvedDependencies
                },
                "runDetails": {
                    "builder": {
                        "id": $ENV.builderId
                    },
                    "metadata": {
                        "invocationId": $ENV.invocationId
                    },
                },
            }
        }' > "/nix/var/nix/provenance$DRV_PATH.slsa.json"

  '';

}
