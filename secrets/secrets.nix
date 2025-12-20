let
  oscar = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEJBfdRDYEZYDg0QOL7duoMWwuF1c4OooAGE6c0NyO0 oscar@harmony" ];
  users = oscar;

  harmony = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkM5uNY0rMy2QMG6IptlxgVl4sQWoeSSNmUp7/f2z1B";
  hoid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ206AeH6b6ErxpHTs0Qux+nKvZUxU3cLt/j3YIkM50C";
  systems = [ harmony hoid ];
in {
  "autobrr-secret.age".publicKeys = oscar ++ [ harmony ];
  "cross-seed-settings-file.age".publicKeys = oscar ++ [ harmony ];
  "cross-seed-headers-file.age".publicKeys = oscar ++ [ harmony ];
  "gluetun.env.age".publicKeys = oscar ++ [ harmony ];
  "homepage-dashboard.env.age".publicKeys = oscar ++ [ harmony ];
  "Harmony_P2P-US-CA-898.conf.age".publicKeys = oscar ++ [ harmony ];
  "minecraft-servers.env.age".publicKeys = oscar ++ [ harmony ];
  "unpackerr.env.age".publicKeys = oscar ++ [ harmony ];
}
