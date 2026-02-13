{ my, ... }:
{
  my.vm.provides = {
    gui.includes = [
      my.vm
      my.vm-bootable._.gui
      my.xfce-desktop
    ];

    tui.includes = [
      my.vm
      my.vm-bootable._.tui
    ];
  };
}
