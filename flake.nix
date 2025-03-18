{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  outputs =
    inputs:
    let
      inherit (inputs) nixpkgs;
      inherit (nixpkgs) lib;
    in
    {
      packages = lib.genAttrs lib.systems.flakeExposed (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          nix-attest-post-build-hook = pkgs.callPackage ./nix-attest-post-build-hook.nix { };
          example = pkgs.writeShellApplication {
            name = "example";
            text = ''
              echo "Hello, world!"
            '';
          };
        }
      );
    };
}
