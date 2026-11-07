{
  my.networkmanager.includes = [
    ({ user, ... }: { nixos.users.users.${user.userName}.extraGroups = [ "networkmanager" ]; })
    {
      nixos.networking.networkmanager.enable = true;

      # `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
      preserve.directories = [
        "/var/lib/NetworkManager" # DHCP leases, secret_key, timestamps
        {
          directory = "/etc/NetworkManager/system-connections";
          mode = "0700";
        } # saved Wi-Fi
      ];
    }
  ];
}
