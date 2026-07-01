{
  description = "Switch Codex CLI and Desktop accounts with isolated CODEX_HOME profiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # Read the version from package.json so the flake never drifts from the
        # rest of the release (see the version-sync guard in make test).
        version = (builtins.fromJSON (builtins.readFile ./package.json)).version;
      in
      {
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "codex-profile";
          inherit version;
          src = ./.;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 bin/codex-profile "$out/bin/codex-profile"
            ln -s codex-profile "$out/bin/codex-profiles"
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Switch Codex CLI and Desktop accounts with isolated CODEX_HOME profiles";
            homepage = "https://github.com/Ducksss/codex-profiles";
            license = licenses.mit;
            platforms = platforms.unix;
            mainProgram = "codex-profile";
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
          name = "codex-profile";
        };
      });
}
