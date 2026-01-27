{ oscarmarshall, ... }:
{
  oscarmarshall.vm = {
    includes = [ ];
    provides = {
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
  };
}
