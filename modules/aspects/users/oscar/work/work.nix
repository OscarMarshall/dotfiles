{
  lib,
  den,
  inputs,
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
      home ? null,
      host ? null,
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
  flake-file.inputs.ponytail = {
    url = "github:DietrichGebert/ponytail/2ed6c52c9d7e5e56942508591085fd45dea277d3";
    flake = false;
  };

  den.aspects.oscar.provides.work =
    args:
    let
      scope = scopeFromArgs args;
    in
    {
      includes = lib.optionals (scope.work or false) (
        builtins.attrValues den.aspects.oscar.provides.work.provides
        ++ (lib.optional (scope.graphical or false) my.slack)
        ++ [ my.openai ]
      );

      homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [ glab ];

        programs.codex = {
          plugins = [ inputs.ponytail ];

          settings.mcp_servers = lib.optionalAttrs (scope.work or false) {
            grafana = {
              args = [
                "mcp-grafana"
                "--enabled-tools"
                "search,datasources,dashboard,elasticsearch,runpanelquery"
                "--disable-write"
                "--log-level"
                "info"
              ];

              command = "${pkgs.uv}/bin/uvx";

              env_vars = [
                "GRAFANA_URL"
                "GRAFANA_USERNAME"
                "GRAFANA_PASSWORD"
              ];

              startup_timeout_sec = 30;
            };

            pagerduty = {
              bearer_token_env_var = "PAGERDUTY_USER_API_KEY";

              enabled_tools = [
                "get_alert_from_incident"
                "get_escalation_policy"
                "get_incident"
                "get_past_incidents"
                "get_related_incidents"
                "get_service"
                "get_team"
                "get_user_data"
                "list_alerts_from_incident"
                "list_escalation_policies"
                "list_incident_change_events"
                "list_incident_notes"
                "list_incidents"
                "list_log_entries"
                "list_oncalls"
                "list_services"
                "list_team_members"
                "list_users"
              ];

              startup_timeout_sec = 30;
              url = "https://mcp.pagerduty.com/mcp";
            };
          };
        };
      };
    };
}
