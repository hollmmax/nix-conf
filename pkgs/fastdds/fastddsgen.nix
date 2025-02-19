{ stdenv, runtimeShell, writeText, fetchFromGitHub, gradle_6, openjdk8, git, perl, cmake }:
let
  pname = "fastddsgen";
  version = "2.1.3";

  src = fetchFromGitHub {
    owner = "eProsima";
    repo = "Fast-DDS-Gen";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-2+zhjdx29T44W7MO5/UDQqjnxb+gdOMf/iS9mmdQHPI=";
  };

  # fake build to pre-download deps into fixed-output derivation
  deps = stdenv.mkDerivation {
    pname = "${pname}-deps";
    inherit src version;
    nativeBuildInputs = [ gradle_6 openjdk8 perl ];

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d);
      gradle --no-daemon -x submodulesUpdate assemble
    '';

    # perl code mavenizes pathes (com.squareup.okio/okio/1.13.0/a9283170b7305c8d92d25aff02a6ab7e45d06cbe/okio-1.13.0.jar -> com/squareup/okio/okio/1.13.0/okio-1.13.0.jar)
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';

    dontStrip = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-NcqfODP8QZISSfllap8vIGfGHfzT+wGxRsJvl7OZHcE=";
  };

  # This is used by, e.g., pdftk to point to local deps repo, but it
  # doesn't work here and we have to patch the sources below. It seems
  # that what's problematic is the GradleBuild-type task for
  # idl-parser, where the settings changes do not propagate.
  #   gradleInit = writeText "init.gradle" ''
  #     logger.lifecycle 'Replacing Maven repositories with ${deps}...'
  #     gradle.projectsLoaded {
  #       rootProject.allprojects {
  #         buildscript {
  #           repositories {
  #             clear()
  #             maven { url '${deps}' }
  #           }
  #         }
  #         repositories {
  #           clear()
  #           maven { url '${deps}' }
  #         }
  #       }
  #     }
  #     gradle.settingsEvaluated { settings ->
  #       settings.pluginManagement {
  #         repositories {
  #           maven { url '${deps}' }
  #         }
  #       }
  #     }
  #   '';

in
stdenv.mkDerivation {
  inherit pname src version;

  nativeBuildInputs = [ gradle_6 openjdk8 ];

  # gradle.settingsEvaluated in the init-script above is not sufficient for a sub-build.
  postPatch = ''
    sed -ie '1i\
    pluginManagement {\
      repositories {\
        maven { url "${deps}" }\
      }\
    }' thirdparty/idl-parser/settings.gradle
    sed -ie "s#mavenCentral()#maven { url '${deps}' }#g" build.gradle
    sed -ie "s#mavenCentral()#maven { url '${deps}' }#g" thirdparty/idl-parser/idl.gradle
  '';

  buildPhase = ''
    runHook preBuild

    export GRADLE_USER_HOME=$(mktemp -d)
    # Run gradle with daemon to make installPhase faster
    gradle --offline -x submodulesUpdate assemble

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    gradle --offline -x submodulesUpdate install --install_path=$out

    # Override the default start script
    cat  <<EOF >$out/bin/fastddsgen
    #!${runtimeShell}
    exec ${openjdk8}/bin/java -jar "$out/share/fastddsgen/java/fastddsgen.jar" "\$@"
    EOF
    chmod a+x "$out/bin/fastddsgen"

    runHook postInstall
  '';
}
