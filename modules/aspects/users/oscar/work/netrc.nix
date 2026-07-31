{
  den.aspects.oscar.provides.work.provides.netrc.homeManager = { config, ... }: {
    # Declared directly in home-manager's age.secrets (not the top-level `secrets` block) - per
    # the comment on claude.nix's github-mcp-server-github-access-token, the `secrets` block in
    # user-level aspects isn't forwarded to age.secrets.
    age.secrets = {
      meraki-jenkins-api-key = {
        intermediary = true;
        rekeyFile = ../../../../../secrets/meraki-jenkins-api-key.age;
      };

      # curl/git (via libcurl) and most other netrc-aware tools only ever look at the literal
      # ~/.netrc path - there's no flag to point them at config.age.secrets.*.path like the
      # EnvironmentFile-style consumers elsewhere in this repo, so `path` is overridden here
      # instead of leaving it at the default secretsDir location.
      meraki-netrc = {
        generator = {
          dependencies = { inherit (config.age.secrets) meraki-jenkins-api-key meraki-teamcity-access-token; };

          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'machine jenkins.ikarem.io\nlogin omarshal\npassword %s\n\n' \
                "$(${decrypt} ${lib.escapeShellArg deps.meraki-jenkins-api-key.file})"
              printf 'machine teamcity.ikarem.io\nlogin omarshal\npassword %s\n' \
                "$(${decrypt} ${lib.escapeShellArg deps.meraki-teamcity-access-token.file})"
            '';
        };

        mode = "0600";
        path = "${config.home.homeDirectory}/.netrc";
      };

      meraki-teamcity-access-token = {
        intermediary = true;
        rekeyFile = ../../../../../secrets/meraki-teamcity-access-token.age;
      };
    };
  };
}
