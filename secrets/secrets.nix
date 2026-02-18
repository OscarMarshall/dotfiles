let
  oscar = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEJBfdRDYEZYDg0QOL7duoMWwuF1c4OooAGE6c0NyO0 oscar@harmony" ];
  harmony = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkM5uNY0rMy2QMG6IptlxgVl4sQWoeSSNmUp7/f2z1B";
in
{
  "autobrr-secret.age".publicKeys = oscar ++ [ harmony ];
  "cross-seed.json.age".publicKeys = oscar ++ [ harmony ];
  "gluetun.env.age".publicKeys = oscar ++ [ harmony ];
  "homepage-dashboard.env.age".publicKeys = oscar ++ [ harmony ];
  "minecraft-servers.env.age".publicKeys = oscar ++ [ harmony ];
  "qbittorrent.env.age".publicKeys = oscar ++ [ harmony ];
  "unpackerr.env.age".publicKeys = oscar ++ [ harmony ];
}
