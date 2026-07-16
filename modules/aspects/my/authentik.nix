{ inputs, ... }:
let
  domain = "silverlight-nex.us";
in
{
  flake-file.inputs.authentik-nix = {
    url = "github:nix-community/authentik-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  my.authentik =
    {
      global ? false,
    }:
    { host, ... }:
    let
      # Unlike every other service's `global` (an ADDITIONAL alias alongside its host-scoped name -
      # see virtual-host.nix), Authentik's own identity is baked into every OIDC issuer URL,
      # redirect URI, and the Terraform provider's target - having it answer on two different
      # names would mean picking one as canonical anyway. So `global` here SWITCHES Authentik's
      # actual served hostname to the bare domain instead of merely aliasing it there; the
      # host-scoped name stops being served at all. `config.services.authentik.nginx.host`
      # (`nixos` below) is this exact value, and other aspects that need Authentik's URL
      # (immich.nix/nextcloud.nix/seerr.nix) read it from there rather than re-deriving it.
      url = if global then "auth.${domain}" else "auth.${host.name}.${domain}";
    in
    {
      # SSO-as-code, managed via terranix (Nix -> Terraform config, see modules/terranix.nix) and
      # the authentik Terraform provider - see dns.nix/meraki.nix for the general pattern
      # (`nix run .#<host>-tf[.plan|.destroy]`, `nix develop .#<host>-tf`,
      # `nix build .#<host>-tf.config`).
      #
      # Every OTHER service's `protected = true;` (see virtual-host.nix) already makes nginx.nix
      # gate that vhost behind Authentik's embedded outpost (`auth_request
      # /outpost.goauthentik.io/auth/nginx`) - but that snippet only WORKS once Authentik itself
      # has a matching Proxy Provider + Application for that hostname, and the embedded outpost
      # has been told to serve it. Until now that pairing was manual (Applications > Providers in
      # the UI); this block generates one `forward_single`-mode provider + application + outpost
      # attachment per `protected` virtual host straight from the SAME quirk data nginx.nix already
      # consumes, so a service can't end up `protected` in nginx but unconfigured in Authentik (or
      # vice versa).
      #
      # Auth: the provider needs an Authentik API token (AUTHENTIK_TOKEN env var - never written
      # into the generated config or Terraform state) and the server URL (not secret, set directly
      # below). Rather than click out a token in the UI, this reuses Authentik's own
      # AUTHENTIK_BOOTSTRAP_TOKEN mechanism (see `services.authentik.environmentFile` below): on
      # Authentik's FIRST boot only, it creates the `akadmin` superuser with that exact token
      # already valid for the API - `authentik-token` below is that same value, flagged
      # `settings.terraform = true;` (modules/terranix.nix) so it lands as `AUTHENTIK_TOKEN` in
      # harmony's generated Terraform env automatically. Run `agenix generate -a && agenix rekey -a`
      # once, `nixos-rebuild switch` harmony so the bootstrap actually runs, and `nix run
      # .#harmony-tf*` just works from then on - no manual `agenix -d | source` step to remember.
      #
      # Because the bootstrap only fires once, rotating `authentik-token` later (e.g. `agenix
      # edit`) does NOT rotate the live API token - that would need a fresh akadmin token minted
      # from the UI (Directory > Tokens) and swapped in by hand, same as any other
      # already-bootstrapped credential.
      #
      # `forward_single` (one provider/application per hostname, matched by the outpost via the
      # request's Host header) rather than `forward_domain` (one shared provider for a whole
      # cookie-domain) because nginx.nix's `protected` snippet is already per-vhost and generic -
      # this mirrors that shape 1:1, and keeps each service's access policy independently
      # assignable later instead of all-or-nothing for the domain.
      #
      # `resource.authentik_outpost.embedded` manages Authentik's own built-in outpost (created
      # automatically, named "authentik Embedded Outpost") directly, IMPORTED rather than created -
      # recreating it would conflict with the instance that already exists out of the box. One-time
      # setup, once per Authentik instance (`nix develop .#<host>-tf`, with `AUTHENTIK_TOKEN`
      # sourced same as any other apply):
      #
      #   uuid=$(curl -s -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
      #     "https://${url}/api/v3/outposts/instances/?search=embedded" | jq -r '.results[0].pk')
      #   tofu import authentik_outpost.embedded "$uuid"
      #
      # This is `authentik_outpost_provider_attachment` deliberately AVOIDED, not merely an
      # alternative - that resource's Create/Delete always `PATCH
      # /api/v3/outposts/instances/{id}/` (its own `Update` is unimplemented; both its fields are
      # `ForceNew`), and that PATCH 404/405s against the embedded outpost on multiple real Authentik
      # versions (see goauthentik/terraform-provider-authentik#341) - a big enough footgun that
      # every independent report in that issue converged on managing `authentik_outpost` directly
      # instead, which is what this does. UNLIKE the per-service resources above,
      # `protocol_providers` here is the outpost's ENTIRE provider list in one shot - the same
      # "replaces everything" shape as `meraki_networks_appliance_firewall_port_forwarding_rules`
      # (see meraki.nix) - so any provider attached to this outpost through the UI, outside the
      # `protected` mechanism below, gets silently removed on the next apply.
      #
      # Social login (`authentik_source_oauth`/`authentik_source_plex` below) is a DIFFERENT thing
      # from the `protected` forward-auth above: it's an identity SOURCE (an extra "Log in with
      # ..." button on Authentik's own login page), not a per-service Provider/Application. Neither
      # Discord (discord.nix is just the desktop client, there's no self-hosted server to front) nor
      # Plex (plex.nix's `virtual-host` is deliberately never `protected` - Plex has its own
      # account/library-based auth) get gated behind Authentik; this only lets people who already
      # have a Discord or Plex.tv account use it to log into Authentik itself (and, once
      # authenticated, whatever `protected` services above already gate).
      #
      # Native OIDC applications (`authentik_provider_oauth2` below) are a THIRD, distinct thing:
      # some services (Immich, Nextcloud, Seerr) have their own OIDC client built in and just need
      # Authentik to hand them a matching Provider + Application, rather than sitting behind
      # forward-auth at all - driven by the `oidc` field on `virtual-host` (virtual-host.nix) each
      # of those services' own aspect sets.
      #
      # Discord/Plex's credentials and every `oidc`-tagged host's `client-secret` are RESOURCE
      # ATTRIBUTES here, not provider-level auth like AUTHENTIK_TOKEN above - Authentik's API has
      # to persist the actual value to work at all, so unlike everything else in this file, these
      # DO end up in Terraform's state file in plaintext once applied (an inherent Terraform
      # limitation, not something the env-var trick can route around) - and harmony-tf's state is
      # committed to this (public) repo (see #516). modules/terranix.nix's `terraform.encryption`
      # (contributed unconditionally for every host, see its own comment) is what actually keeps
      # these out of the plaintext git history; `settings.terraform = "variable";` (below, on each
      # secret) is just how their values reach the `variable`s that encryption config wraps.
      terranix =
        { virtual-host, lib, ... }:
        let
          protected-hosts = lib.filter (vh: vh.protected or false) virtual-host;
          oidc-hosts = lib.filter (vh: vh ? oidc) virtual-host;
          hostname-of = vh: vh.url or "${vh.name}.${host.name}.${domain}";
          # Every hostname a `global` virtual-host actually answers on: its own (derived or
          # overridden) name, plus the canonical `<name>.<domain>` too - see virtual-host.nix's
          # `oidc` field comment for why both need a redirect URI registered, not just one.
          # `unique` because a `global` host whose `url` override IS already the canonical name
          # (storyteller.nix) would otherwise register every redirect URI twice.
          hostnames-of = vh: lib.unique ([ (hostname-of vh) ] ++ lib.optional (vh.global or false) "${vh.name}.${domain}");

          # Reuses each service's own `virtual-host.icon` (virtual-host.nix) rather than picking
          # Authentik icons separately, translating Homepage's icon shorthands into the plain URL
          # Authentik's `meta_icon` expects. Only the forms actually in use are handled - an
          # absolute URL as-is, "mdi-<name>" via jsdelivr's @mdi/svg CDN, and a bare dashboard-icons
          # filename - so an icon written in one of Homepage's OTHER shorthands (`si-`, `sh-`) fails
          # loudly here instead of silently landing on a broken image.
          icon-url-of =
            icon:
            if lib.hasPrefix "https://" icon then
              icon
            else if lib.hasPrefix "mdi-" icon then
              "https://cdn.jsdelivr.net/npm/@mdi/svg/svg/${lib.removePrefix "mdi-" icon}.svg"
            else if lib.hasSuffix ".svg" icon then
              "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/${icon}"
            else
              throw "my.authentik: don't know how to turn icon \"${icon}\" into a meta_icon URL";

          # Mirrors `env-var-for` (modules/terranix.nix) exactly - the `TF_VAR_` prefix a
          # `settings.terraform = "variable";` secret surfaces under is added programmatically
          # there, not baked into the secret's name, so the Terraform `variable` it populates is
          # just this transform of the secret's own name. Also used for every `oidc`-tagged virtual
          # host's own `client-secret` below, so all of these stay derived from one place instead
          # of hand-typed twice per secret.
          tf-var-name-of = secret: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] secret);

          # Discord: create an OAuth2 app at https://discord.com/developers/applications, copy its
          # Client ID below (not secret - it's public in every OAuth redirect), put the Client
          # Secret in the `discord-client-secret` age file (one-time `agenix edit
          # secrets/discord-client-secret.age`, then `agenix rekey -a`), and add
          # `https://${url}/source/oauth/callback/discord/` as that app's OAuth2 redirect URI.
          discord-client-id = "1525363641598083102";

          # Plex: unlike Discord, this ID isn't issued BY Plex - it's an arbitrary, stable string
          # Authentik uses to identify itself to plex.tv (the `X-Plex-Client-Identifier`). Any
          # value works and never needs to change; no action needed.
          plex-client-id = "silverlight-nex-us-authentik";

          # harmony's Plex server `machineIdentifier` (`curl http://localhost:32400/identity` on
          # harmony) - restricts Plex login to people with access to this server; left empty, ANY
          # Plex.tv account could log into Authentik instead.
          plex-allowed-servers = [ "8c5824dcf35bfbe5a6f73239e4150ab2f563f624" ];
        in
        # `lib.foldl' lib.recursiveUpdate`, not `//` - every branch below declares a top-level
        # `resource`/`data` attrset, and `//` only shallow-merges, which would make each later
        # branch silently clobber the earlier ones' resources instead of adding to them.
        lib.foldl' lib.recursiveUpdate
          {
            terraform.required_providers.authentik = {
              source = "goauthentik/authentik";
              version = "~> 2026";
            };

            # `token` isn't set here - the provider reads it from AUTHENTIK_TOKEN (see above); `url`
            # isn't secret, so it's set directly rather than round-tripped through an env var.
            provider.authentik.url = "https://${url}";

            data.authentik_flow = {
              default-authorization-flow.slug = "default-provider-authorization-implicit-consent";
              default-invalidation-flow.slug = "default-provider-invalidation-flow";
              # Distinct from the provider-authorization flow above - these are Authentik's built-in
              # flows for external identity SOURCES (Discord/Plex/etc.), not Providers.
              default-source-authentication.slug = "default-source-authentication";
              default-source-enrollment.slug = "default-source-enrollment";
            };

            variable.DISCORD_CLIENT_SECRET.sensitive = true;
            variable.PLEX_TOKEN.sensitive = true;

            # Groups live here rather than on the service that consumes them: they're a DIRECTORY
            # concept (authentik.nix owns every `authentik_*` resource, the way dns.nix owns every
            # `cloudflare_*` one), and nothing stops a second service keying off the same group
            # later. Only their NAMES matter to a consumer - Authentik's default `profile` scope
            # emits `groups` as a list of group names, and Storyteller maps those names to its own
            # permissions (see storyteller.nix).
            #
            # MEMBERSHIP is deliberately not managed here: `users` on `authentik_group` is
            # `Optional` AND `Computed` in the Terraform provider, so omitting it means "leave
            # whatever's there alone" rather than "empty it" - unlike `authentik_outpost`'s
            # `protocol_providers` above, which really does replace the whole list. Accounts arrive
            # by Discord/Plex enrollment and don't exist in this config, so assign people through
            # Authentik's UI (Directory > Groups) and applies won't fight you over it.
            resource.authentik_group = lib.genAttrs [ "storyteller-admins" "storyteller-users" ] (name: {
              inherit name;
            });

            resource.authentik_source_oauth.discord = {
              name = "Discord";
              slug = "discord";
              authentication_flow = "\${data.authentik_flow.default-source-authentication.id}";
              enrollment_flow = "\${data.authentik_flow.default-source-enrollment.id}";
              provider_type = "discord";
              consumer_key = discord-client-id;
              consumer_secret = "\${var.${tf-var-name-of "discord-client-secret"}}";
            };

            resource.authentik_source_plex.plex = {
              name = "Plex";
              slug = "plex";
              authentication_flow = "\${data.authentik_flow.default-source-authentication.id}";
              enrollment_flow = "\${data.authentik_flow.default-source-enrollment.id}";
              client_id = plex-client-id;
              plex_token = "\${var.${tf-var-name-of "plex-token"}}";
              allowed_servers = plex-allowed-servers;
              allow_friends = true;
            };
          }
          [
            (lib.optionalAttrs (protected-hosts != [ ]) {
              resource.authentik_provider_proxy = lib.listToAttrs (
                map (vh: {
                  name = vh.name;
                  value = {
                    name = vh.name;
                    mode = "forward_single";
                    external_host = "https://${hostname-of vh}";
                    authorization_flow = "\${data.authentik_flow.default-authorization-flow.id}";
                    invalidation_flow = "\${data.authentik_flow.default-invalidation-flow.id}";
                  };
                }) protected-hosts
              );

              resource.authentik_application = lib.listToAttrs (
                map (vh: {
                  name = vh.name;
                  value = {
                    name = vh.label or vh.name;
                    slug = vh.name;
                    protocol_provider = "\${authentik_provider_proxy.${vh.name}.id}";
                  }
                  // lib.optionalAttrs (vh ? icon) { meta_icon = icon-url-of vh.icon; }
                  // lib.optionalAttrs (vh ? group) { inherit (vh) group; };
                }) protected-hosts
              );

              resource.authentik_outpost.embedded = {
                name = "authentik Embedded Outpost";
                protocol_providers = map (vh: "\${authentik_provider_proxy.${vh.name}.id}") protected-hosts;
              };
            })
            (lib.optionalAttrs (oidc-hosts != [ ]) {
              variable = lib.genAttrs (map (vh: tf-var-name-of vh.oidc.client-secret) oidc-hosts) (_: {
                sensitive = true;
              });

              # An OAuth2 provider returns ONLY the claims whose scope mapping is attached to it -
              # `ScopeMapping.objects.filter(provider=provider, scope_name__in=scopes_from_client)`
              # in authentik's userinfo view - and the Terraform provider's `property_mappings` is
              # Optional WITHOUT `Computed`, so leaving it unset doesn't inherit anything: it
              # attaches nothing, and userinfo comes back with no `email`, no `profile`, no
              # `groups`. (Authentik's own UI pre-selects these three when you click a provider
              # together, which is why this only bites configs built through the API.) These are the
              # same three defaults that form picks. `profile` is what carries the `groups` claim -
              # see the default mapping's expression, `[group.name for group in
              # request.user.groups.all()]` - so group-based permissions in a downstream app
              # (storyteller.nix) depend on this too, not just on a `groups` scope being requested.
              data.authentik_property_mapping_provider_scope.oidc-defaults.managed_list = [
                "goauthentik.io/providers/oauth2/scope-openid"
                "goauthentik.io/providers/oauth2/scope-email"
                "goauthentik.io/providers/oauth2/scope-profile"
              ];

              resource.authentik_provider_oauth2 = lib.listToAttrs (
                map (vh: {
                  name = "${vh.name}-oidc";
                  value = {
                    name = vh.name;
                    client_id = vh.name;
                    client_secret = "\${var.${tf-var-name-of vh.oidc.client-secret}}";
                    property_mappings = "\${data.authentik_property_mapping_provider_scope.oidc-defaults.ids}";
                    allowed_redirect_uris = lib.concatMap (
                      hostname:
                      map (path: {
                        matching_mode = "strict";
                        redirect_uri_type = "authorization";
                        url = "https://${hostname}${path}";
                      }) vh.oidc.redirect-paths
                    ) (hostnames-of vh);
                    authorization_flow = "\${data.authentik_flow.default-authorization-flow.id}";
                    invalidation_flow = "\${data.authentik_flow.default-invalidation-flow.id}";
                  };
                }) oidc-hosts
              );

              resource.authentik_application = lib.listToAttrs (
                map (vh: {
                  name = "${vh.name}-oidc";
                  value = {
                    name = vh.label or vh.name;
                    slug = vh.name;
                    protocol_provider = "\${authentik_provider_oauth2.${vh.name}-oidc.id}";
                  }
                  // lib.optionalAttrs (vh ? icon) { meta_icon = icon-url-of vh.icon; }
                  // lib.optionalAttrs (vh ? group) { inherit (vh) group; };
                }) oidc-hosts
              );
            })
          ];

      # No `port`: authentik-nix's own module wires `services.nginx.virtualHosts.${url}.locations`
      # directly (see `services.authentik.nginx` below), same pattern as Nextcloud's PHP-FPM vhost.
      # This entry only exists so nginx.nix's `serverAliases`/global-toggle and homepage.nix's
      # dashboard tile can pick Authentik up like every other service - `url` MUST be given
      # explicitly (not left to nginx.nix's own `${name}.${host.name}.${domain}` default), or
      # nginx.nix and `services.authentik.nginx.host` below would disagree on Authentik's vhost
      # name and produce two separate, non-merging `virtualHosts` entries instead of one. `global`
      # is still passed through so dns.nix keeps creating the canonical record - see the `url`
      # binding's comment above for why Authentik's `global` means something stronger than every
      # other service's (replace, not merely alias).
      virtual-host = {
        name = "auth";
        host = host.name;
        inherit global url;
        label = "Authentik";
        icon = "authentik.svg";
        group = "Infra";
        homepage = {
          description = "Single sign-on";
        };
      };

      secrets = { secrets, ... }: {
        authentik-secret-key = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -base64 60";
          intermediary = true;
        };
        # Consumed both by `authentik.env` below (so Authentik mints it as `akadmin`'s API token
        # on first boot, under the DIFFERENT env var name that bootstrap mechanism expects) and,
        # via `settings.terraform = true;`, by harmony's shared Terraform env (as `AUTHENTIK_TOKEN`)
        # - see the `terranix` field's comment for why a bootstrap token rather than a UI-created
        # one.
        authentik-token = {
          generator.script = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
          intermediary = true;
          settings.terraform = true;
        };
        "authentik.env".generator = {
          dependencies = { inherit (secrets) authentik-secret-key authentik-token; };
          script =
            {
              lib,
              decrypt,
              deps,
              ...
            }:
            ''
              printf 'AUTHENTIK_SECRET_KEY=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.authentik-secret-key.file})"
              printf 'AUTHENTIK_BOOTSTRAP_TOKEN=%s\n' "$(${decrypt} ${lib.escapeShellArg deps.authentik-token.file})"
            '';
        };

        # Both come from an external dashboard (Discord's, Plex's own account), so - unlike the
        # generated secrets above - these use `rekeyFile` and need a one-time `agenix edit` (see
        # the `terranix` field's comment for where each value comes from), same as
        # `cloudflare-api-token`/`meraki-dashboard-api-key`. `settings.terraform = "variable";`
        # (not `= true;`) because they're only ever consumed as Terraform `variable`s, never by a
        # NixOS service directly - see modules/terranix.nix's header comment on the two modes.
        discord-client-secret = {
          rekeyFile = ../../../secrets/discord-client-secret.age;
          intermediary = true;
          settings.terraform = "variable";
        };

        plex-token = {
          rekeyFile = ../../../secrets/plex-token.age;
          intermediary = true;
          settings.terraform = "variable";
        };
      };

      nixos = { config, ... }: {
        imports = [ (inputs.authentik-nix.nixosModules.default or { }) ];

        services.authentik = {
          enable = true;
          environmentFile = config.age.secrets."authentik.env".path;
          settings.disable_startup_analytics = true;
          nginx = {
            enable = true;
            enableACME = true;
            host = url;
          };
        };

        # nginx.nix forces `HttpOnly` onto every proxied cookie, but Authentik's frontend needs to
        # read its CSRF cookie via JavaScript (it echoes the value back as the X-Authentik-Csrf
        # header). With HttpOnly forced on, that read fails and Authentik rejects the empty token
        # with "CSRF token ... incorrect length". Reset the cookie rewrite for this vhost only.
        services.nginx.virtualHosts.${url}.extraConfig = ''
          proxy_cookie_path / /;
        '';
      };
    };
}
