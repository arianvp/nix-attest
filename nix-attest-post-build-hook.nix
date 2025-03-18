{
  writeShellApplication,
  jq,
  nix,
  python3Packages,
}:


writeShellApplication {
  name = "nix-attest-post-build-hook";
  runtimeInputs = [
    jq
    nix
  ];
  text = ''
    export IFS=' '
  
    # We add both narHash (which in-toto does not define) and sha256 (which in-toto does define)
    # the sha256 is over the nar-serialization. So people should do `nix store dump-path` as file to verify instead of a directory

    subjects=$(for path in $OUT_PATHS; do
        subject=$(nix path-info "$path" --json | jq --arg path "$path" '.[$path]| {name:$path, digest:{narHash:.narHash}}')
        narHash=$(echo "$subject" | jq -r '.digest.narHash')
        sha256="$(nix hash convert --to base16 "$narHash")"
        echo "$subject" | jq --arg sha256 "$sha256" '.digest.sha256=$sha256'
    done  | jq -s .)
    derivation=$(nix derivation show "$DRV_PATH" | jq --arg DRV_PATH "$DRV_PATH" '.[$DRV_PATH]')

    # TODO: For nix substitution we do not want to have build time dependencies but runtime dependencies

    inputDrvs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputDrvs | to_entries | map(.key as $key | .value.outputs[]|"\($key)^\(.)")[]')
    inputSrcs=$(jq -r -n --argjson derivation "$derivation" '$derivation.inputSrcs[]')

    resolvedDependencies=$({ echo "$inputDrvs"; echo "$inputSrcs"; } | while IFS= read -r path; do
        dep=$(nix path-info --recursive "$path" --json | jq 'to_entries | map({name:.key, digest:{narHash:.value.narHash}})[]')
        narHash=$(echo "$dep" | jq -r '.digest.narHash')
        sha256="sha256:$(nix hash convert --to base16 "$narHash")"
        echo "$dep" | jq --arg sha256 "$sha256" '.digest.sha256=$sha256'
    done | jq -s .)

    jq -n \
        --argjson derivation "$derivation" \
        --argjson resolvedDependencies "$resolvedDependencies" \
        --argjson subject "$subjects" \
        '{
            "_type": "https://in-toto.io/Statement/v1",
            "subject": $subject,
            "predicateType": "https://slsa.dev/provenance/v1",
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
        }' > "$(basename "$DRV_PATH").slsa.json"

  '';

}
