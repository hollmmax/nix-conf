{ version
, src-hash
}:
{ lib
, autoPatchelfHook
, autoconf
, automake
, buildFHSUserEnvBubblewrap
, fetchurl
, libglvnd
, libjpeg
, libpng
, libtiff
, libusb1
, libxkbcommon
, llvmPackages_8
, makeWrapper
, patchelf
, pigz
, python37
, runCommandLocal
, stdenv
, systemd
, vulkan-loader
, xorg
}:

let
  extraLibs = [
    libglvnd
    libxkbcommon
    systemd                     # for libudev
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcursor
    xorg.libXext
    xorg.libXi
    xorg.libXinerama
    xorg.libXrandr
    xorg.libXxf86vm
    vulkan-loader
  ];
  pythonLibs = [
    libpng
    libtiff
    stdenv.cc.cc.lib
    (libjpeg.override { enableJpeg8 = true; })
  ];
  python-env = python37.withPackages (p: with p; [  # For PythonAPI/examples
    pygame
    numpy
    setuptools # Requires nixpkgs-22.05
  ]);
  python4carla = runCommandLocal "python4carla" { nativeBuildInputs = [ makeWrapper ]; } ''
      mkdir -p $out/bin
      makeWrapper "${python-env}/bin/python" $out/bin/python \
        --prefix LD_LIBRARY_PATH : '${lib.makeLibraryPath pythonLibs}'
    '';
in
stdenv.mkDerivation rec {
  pname = "carla-bin";
  inherit version;
  src = fetchurl {
    url = "https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/CARLA_${version}.tar.gz";
    sha256 = src-hash;
  };

  nativeBuildInputs = [
    pigz
    patchelf
  ];
  buildInputs = [
    autoPatchelfHook
    makeWrapper
    llvmPackages_8.openmp
    libusb1
    python4carla              # for patchShebangs PythonAPI
  ];

  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    cd $out
    pigz -dc $src | tar xf -
  '';

  postFixup = ''
    for i in libChronoModels_robot.so libChronoEngine_vehicle.so libChronoEngine.so libChronoModels_vehicle.so; do
      patchelf --replace-needed libomp.so.5 libomp.so $out/CarlaUE4/Plugins/Carla/CarlaDependencies/lib/$i
    done
    patchShebangs --host PythonAPI
    wrapProgram $out/CarlaUE4.sh --prefix LD_LIBRARY_PATH : '${lib.makeLibraryPath extraLibs}'
  '';
}
