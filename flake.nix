{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  nixConfig.post-build-hook = ./hook.sh;
  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
    in
    {
      hook = ./hook.sh;
      packages = lib.genAttrs lib.systems.flakeExposed (
        system: with nixpkgs.legacyPackages.${system}; {
          example =
            runCommand "example"
              {
                outputs = [
                  "bin"
                  "lib"
                  "out"
                ];
                buildInputs = [ hello ];
              }
              ''
                hello > $out
                hello > $bin
                hello > $lib
              '';
        }
      );
    };
}
