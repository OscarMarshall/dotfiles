{
  den,
  lib,
  my,
  ...
}:
let
  # `home` is checked before `host`: a standalone home named `user@undeclared-host`
  # (e.g. dev203) gets a synthetic `host = { name = ...; }` from den purely so
  # host-keyed cross-entity policies can match on `host.name` - it never carries
  # `work`/`graphical`. The real attributes always live on `home` for those.
  scopeFromArgs =
    {
      host ? null,
      home ? null,
      ...
    }@args:
    if home != null then
      home
    else if host != null then
      host
    else
      args;
in
{
  den.aspects.oscar.provides.work =
    args:
    let
      scope = scopeFromArgs args;
    in
    {
      includes = lib.optionals (scope.work or false) (
        builtins.attrValues den.aspects.oscar.provides.work.provides
        ++ (lib.optional (scope.graphical or false) my.slack)
        ++ [ (my.openai { chatgpt = scope.graphical or false; }) ]
      );

      homeManager = { pkgs, ... }: {
        home.packages = [ glab ];
        programs.codex.settings.mcp_servers = lib.optionalAttrs (scope.work or false) {
          grafana = {
            command = "${pkgs.uv}/bin/uvx";
            args = [
              "mcp-grafana"
              "--enabled-tools"
              "search,datasources,dashboard,elasticsearch,runpanelquery"
              "--disable-write"
              "--log-level"
              "info"
            ];
            startup_timeout_sec = 30;
            env_vars = [
              "GRAFANA_URL"
              "GRAFANA_USERNAME"
              "GRAFANA_PASSWORD"
            ];
          };
        };
      };
    };
}
