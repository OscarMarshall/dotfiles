let
  oscar = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEJBfdRDYEZYDg0QOL7duoMWwuF1c4OooAGE6c0NyO0 oscar@harmony" ];
  users = oscar;

  harmony = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkM5uNY0rMy2QMG6IptlxgVl4sQWoeSSNmUp7/f2z1B";
  hoid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ206AeH6b6ErxpHTs0Qux+nKvZUxU3cLt/j3YIkM50C";
  systems = [ harmony hoid ];
in {
  "cross-seed-settings-file.age".publicKeys = oscar ++ systems;
  "cross-seed-headers-file.age".publicKeys = oscar ++ systems;
  "homepage-dashboard-environment-file.age".publicKeys = oscar ++ systems;
  "proton-vpn-private-key.age".publicKeys = oscar ++ systems;
  "Harmony_P2P-US-CA-898.conf.age".publicKeys = oscar ++ [ harmony ];
}
