{
  description = "wrk2 - a HTTP benchmarking tool based mostly on wrk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Extract version from src/wrk.h
        version = builtins.head (builtins.match ''.*#define VERSION[[:space:]]+"([^"]+)".*'' (builtins.readFile ./src/wrk.h));

        sources = [
          "wrk" "net" "ssl" "aprintf" "stats" "script"
          "units" "ae" "zmalloc" "http_parser" "tinymt64" "hdr_histogram"
        ];

        compileSource = name: ''
          echo "CC ${name}.c"
          $CC -std=c99 -Wall -O2 -D_REENTRANT \
              -I ${pkgs.luajit}/include/luajit-2.1 \
              -I ${pkgs.openssl.dev}/include \
              -I ${pkgs.zlib.dev}/include \
              -I src \
              -c -o obj/${name}.o src/${name}.c
        '';
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "wrk2";
          inherit version;

          src = ./.;

          nativeBuildInputs = [ pkgs.luajit ];

          buildInputs = [
            pkgs.openssl
            pkgs.luajit
            pkgs.zlib
          ];

          buildPhase = ''
            mkdir -p obj

            echo "LUAJIT src/wrk.lua"
            ${pkgs.luajit}/bin/luajit -b src/wrk.lua obj/bytecode.o

            ${pkgs.lib.concatMapStringsSep "\n" compileSource sources}

            echo "LINK wrk"
            $CC -o wrk obj/*.o \
                -L ${pkgs.luajit}/lib \
                -L ${pkgs.openssl.out}/lib \
                -L ${pkgs.zlib}/lib \
                -lluajit-5.1 -lpthread -lm -lcrypto -lssl -lz
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp wrk $out/bin/wrk2
          '';

          meta = with pkgs.lib; {
            description = "wrk2 - a HTTP benchmarking tool based mostly on wrk";
            homepage = "https://github.com/giltene/wrk2";
            license = licenses.bsd3;
            platforms = platforms.unix;
            mainProgram = "wrk2";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.luajit
            pkgs.openssl
            pkgs.gnumake
          ];
        };
      }
    );
}
