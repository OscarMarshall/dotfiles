{
  my.storyteller =
    {
      global ? false,
    }:
    { host, ... }:
    let
      port = 8001;
    in
    {
      dataset = {
        pool = "metalminds";
        name = "storyteller";
      };

      virtual-host = {
        name = "storyteller";
        host = host.name;
        protected = true;
        inherit port global;
        label = "Storyteller";
        # No dashboard-icons entry for this app - its own upstream logo instead.
        icon = "https://gitlab.com/storyteller-platform/storyteller/-/raw/main/applications/docs/static/img/Storyteller_Logo.png";
        group = "Media";
        homepage = {
          description = "Read-aloud book alignment";
        };
      };

      secrets = { secrets, ... }: {
        storyteller-secret-key = {
          generator.script = "alnum";
          intermediary = true;
        };
        "storyteller.env".generator = {
          dependencies = { inherit (secrets) storyteller-secret-key; };
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'STORYTELLER_SECRET_KEY="%s"\n' "$(
                ${decrypt} ${lib.escapeShellArg deps.storyteller-secret-key.file}
              )"
            '';
        };
      };

      nixos = { config, ... }: {
        virtualisation.oci-containers.containers.storyteller = {
          # Pinned to the current `latest` tag's digest at the time this was written --
          # storyteller-platform doesn't cut stable releases, so there's nothing more specific to
          # pin to. Re-resolve via the GitLab registry API if bumping:
          #   curl -s "https://gitlab.com/api/v4/projects/67994333/registry/repositories/8429296/tags/latest"
          image = "registry.gitlab.com/storyteller-platform/storyteller@sha256:a15609ec102de6aace73b5aae3794f7f8e9f40ed3ac2f57e923ef72daa505668";
          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];
          volumes = [ "/metalminds/storyteller:/data" ];
          environment.ENABLE_WEB_READER = "true";
          environmentFiles = [ config.age.secrets."storyteller.env".path ];
        };
      };
    };
}
