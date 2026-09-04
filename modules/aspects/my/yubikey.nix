# PC/SC stack for the YubiKey smartcard interface.
#
# age-plugin-yubikey (agenix-rekey, and `nix run .#install-ssh-key`) talks to the PIV applet over
# pcscd. Without it every operation fails with "yubikey plugin: Could not open YubiKey with serial
# ...". GnuPG's scdaemon otherwise claims the USB CCID interface exclusively and blocks pcscd, so
# route scdaemon through pcscd as well (`disable-ccid`) rather than letting the two fight over the
# reader. A stuck `scdaemon` may still need `gpgconf --kill scdaemon` right before an age/YubiKey
# operation, but the two no longer hard-conflict.
{
  my.yubikey = {
    hmLinux.programs.gpg.scdaemonSettings.disable-ccid = true;
    nixos.services.pcscd.enable = true;
  };
}
