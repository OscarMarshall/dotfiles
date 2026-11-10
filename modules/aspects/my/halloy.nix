{
  my.halloy = { user, ... }: {
    homeManager.programs.halloy = {
      enable = true;

      # Halloy refuses to start without at least one server. No SASL yet: registering the nick with
      # NickServ and adding `sasl.plain.password_file` from a secret is a follow-up.
      settings.servers.liberachat = {
        channels = [ ];
        nickname = "OscarMarshall";
        server = "irc.libera.chat";
      };
    };

    # Chat history and logs; the config itself is Home Manager-managed. `preserve`
    # (modules/aspects/my/preserve.nix) is inert without my.preservation.
    preserve.users.${user.userName}.directories = [ ".local/share/halloy" ];
  };
}
