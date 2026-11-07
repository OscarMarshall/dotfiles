{
  my.gpg = { user, ... }: {
    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.pinentry-all ];
      programs.gpg.enable = true;
      services.gpg-agent.enable = true;
    };

    # Keyring + trustdb. `preserve` (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [
      {
        directory = ".gnupg";
        mode = "0700";
      }
    ];
  };
}
