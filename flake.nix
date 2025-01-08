{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  nixConfig.post-build-hook = ./hook.sh;
  outputs = { self, nixpkgs }: {

    packages.aarch64-linux = with nixpkgs.legacyPackages.aarch64-linux; {
      example = runCommand "example" {
        outputs = [ "bin" "lib" "out" ];
        buildInputs = [ hello ];
      } ''
        hello > $out
        hello > $bin
        hello > $lib
      '';
    };
  };
}
