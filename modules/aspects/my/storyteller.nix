{ my, ... }:
{
  my.storyteller =
    let
      port = 8001;
    in
    {
      includes = with my; [ (nginx._.virtual-host "storyteller.harmony.silverlight-nex.us" port) ];

      secrets =
        { secrets, ... }:
        {
          storyteller-secret-key.generator.script = "alnum";
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

      nixos =
        { config, ... }:
        {
          virtualisation.oci-containers.containers.storyteller = {
            image = "registry.gitlab.com/storyteller-platform/storyteller:latest";
            ports =
              let
                port' = toString port;
              in
              [ "127.0.0.1:${port'}:${port'}" ];
            volumes = [ "/metalminds/storyteller:/data" ];
            environment = {
              ENABLE_WEB_READER = "true";
            };
            environmentFiles = [ config.age.secrets."storyteller.env".path ];
          };
        };
    };
}
