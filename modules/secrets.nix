{ secrets, ... }:

{
  age.secrets = {
    autobrr-secret.file = secrets/autobrr-secret.age;
    cross-seed-settings-file.file = secrets/cross-seed-settings-file.age;
    cross-seed-headers-file = {
      file = secrets/cross-seed-headers-file.age;
      owner = "qbittorrent";
      group = "qbittorrent";
    };
    "homepage-dashboard.env".file = secrets/homepage-dashboard.env.age;
    "Harmony_P2P-US-CA-898.conf".file = secrets/Harmony_P2P-US-CA-898.conf.age;
    "minecraft-servers.env".file = secrets/minecraft-servers.env.age;
    "unpackerr.env".file = secrets/unpackerr.env.age;
  };
}
