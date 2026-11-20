{
  description = "Ambiente de desenvolvimento Flutter (Web e Android) com Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        cmdLineToolsVersion = "latest";
        platformToolsVersion = "latest";
        buildToolsVersions = [ "34.0.0" "35.0.0" "36.0.0" ];
        platformVersions = [ "34" "35" "36" ];
        includeNDK = true;
        ndkVersions = [ "28.2.13676358" ];
        includeCmake = true;
        cmakeVersions = [ "3.22.1" ];
        extraLicenses = [
          "android-googletv-license"
          "android-googlexr-license"
          "android-sdk-arm-dbt-license"
          "android-sdk-preview-license"
          "google-gdk-license"
          "intel-android-extra-license"
          "intel-android-sysimage-license"
          "microxr-sysimage-license"
          "mips-android-sysimage-license"
        ];
        includeEmulator = false;
      };

      androidSdk = androidComposition.androidsdk;
      jdk = pkgs.jdk17;

      # Script auxiliar para executar o Flutter Web na porta 3000
      runWebScript = pkgs.writeShellScriptBin "run-web" ''
        echo "Iniciando Flutter Web em http://localhost:3000..."
        exec flutter run -d web-server --web-port=3000 --web-hostname=localhost "$@"
      '';

      # Script auxiliar de diagnóstico do ambiente
      checkEnvScript = pkgs.writeShellScriptBin "check-env" ''
        echo "================ Diagnóstico do Ambiente ================"
        echo "Flutter:"
        flutter --version | head -n 3
        echo ""
        echo "Dart:"
        dart --version
        echo ""
        echo "Android SDK (ADB):"
        adb version | head -n 2
        echo ""
        echo "Java Development Kit (JDK):"
        java -version 2>&1 | head -n 2
        echo ""
        echo "Flutter Doctor:"
        flutter doctor -v
        echo "=========================================================="
      '';
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "flutter-dev-shell";

        buildInputs = [
          pkgs.flutter
          androidSdk
          jdk
          pkgs.git
          pkgs.curl
          pkgs.unzip
          pkgs.zip
          pkgs.pkg-config
          pkgs.gnumake
          pkgs.supabase-cli

          # Scripts utilitários
          runWebScript
          checkEnvScript
        ];

        # Variáveis de ambiente exigidas
        ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
        JAVA_HOME = "${jdk}";

        shellHook = ''
          export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"
          export PUB_CACHE="''${PUB_CACHE:-$HOME/.pub-cache}"
          export PATH="$PUB_CACHE/bin:$PATH"
        '';
      };
    };
}
