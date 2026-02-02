{ oscarmarshall, ... }:
{
  oscarmarshall.vm.provides = {
    gui.includes = [
      oscarmarshall.vm
      oscarmarshall.vm-bootable._.gui
      oscarmarshall.xfce-desktop
    ];

    tui.includes = [
      oscarmarshall.vm
      oscarmarshall.vm-bootable._.tui
    ];
  };
}
