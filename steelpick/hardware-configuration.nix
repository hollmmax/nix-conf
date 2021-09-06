# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      <nixos-hardware/common/cpu/intel>
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/cb76e15c-a0d0-4b3e-983c-48fe2babc765";
      fsType = "btrfs";
      options = [ "subvol=nixos" ];
    };

  fileSystems."/mnt/debian" = {
    device = "/dev/disk/by-uuid/cb76e15c-a0d0-4b3e-983c-48fe2babc765";
  };

  fileSystems."/home" = { options = [ "bind" ]; device = "/mnt/debian/home"; };


  # fileSystems."/mnt/debian/dev"  = { options = [ "bind" ]; device = "/dev"; };
  # fileSystems."/mnt/debian/sys"  = { options = [ "bind" ]; device = "/sys"; };
  # fileSystems."/mnt/debian/proc" = { options = [ "bind" ]; device = "/proc"; };
  #fileSystems."/mnt/debian/tmp/.X11-unix" = { options = [ "bind" ]; device = "/tmp/.X11-unix"; };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/7a925611-876c-4a2d-98aa-ced6f63bcdf2"; }
    ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];
}

# Local Variables:
# compile-command: "nixos-rebuild switch"
# End:
