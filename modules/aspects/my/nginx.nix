{
  my.nginx = {
    port-forward = [
      {
        name = "http";
        port = 80;
        restrict-to-cloudflare = true;
      }
      {
        name = "https";
        port = 443;
        restrict-to-cloudflare = true;
      }
    ];

    nixos =
      {
        virtual-host,
        host,
        lib,
        config,
        ...
      }:
      let
        domain = "silverlight-nex.us";

        # Address of Authentik's embedded outpost, used to gate `protected` virtual hosts behind
        # forward-auth. Matches the address authentik-nix's own nginx integration proxies to.
        authentikOutpost = "https://127.0.0.1:9443";
        # Looked up rather than referenced directly, since `my.authentik` (and thus the
        # `services.authentik.*` options) may not be included on every host that uses `my.nginx`.
        # Only forced — and only throws — when a `protected` virtual host actually needs it.
        authentikHost =
          let
            host = lib.attrByPath [ "services" "authentik" "nginx" "host" ] null config;
          in
          if host != null then
            host
          else
            throw "my.nginx: a `protected` virtual host requires my.authentik (or another module setting services.authentik.nginx.host) to be included on this host";

        # nginx only inherits a parent context's `add_header` directives into a location that
        # doesn't declare any of its own. Forward-auth locations below need `add_header
        # Set-Cookie` to propagate Authentik's session cookie, which would otherwise silently
        # drop the site-wide security headers from `appendHttpConfig` for those locations.
        securityHeaders = ''
          add_header Strict-Transport-Security $hsts_header;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
        '';
      in
      {
        security.acme = {
          acceptTerms = true;
          defaults.email = "letsencrypt@alias.oscarmarshall.com";
        };

        services.nginx = {
          enable = true;

          recommendedBrotliSettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;

          virtualHosts = lib.listToAttrs (
            map (
              vh:
              let
                # Every service is namespaced under its host by default (immich.harmony.…), so
                # multiple hosts can run the same service without colliding on one wildcard DNS
                # entry. A service opts into also being reachable at the bare, host-agnostic name
                # (immich.…) via `global = true;` on its `virtual-host` record — surfaced as an
                # nginx `serverAlias`, which nixos's ACME integration automatically adds as a SAN
                # on the same certificate.
                url = vh.url or "${vh.name}.${host.name}.${domain}";
              in
              lib.nameValuePair url (
                {
                  forceSSL = true;
                  enableACME = true;
                  serverAliases = lib.optionals (vh.global or false) [ "${vh.name}.${domain}" ];
                  # appendHttpConfig's proxy_cookie_path rewrite appends its own secure/HttpOnly/
                  # SameSite flags to every Set-Cookie header, even ones a backend already set its
                  # own correct flags on. That produces a Set-Cookie with duplicated attributes,
                  # which browsers can silently refuse to store — breaking login for any backend
                  # that manages its own cookie security (e.g. Immich). Opt out per host via
                  # `preserveCookieFlags = true;` on the `virtual-host` record.
                  extraConfig = lib.optionalString (vh.preserveCookieFlags or false) ''
                    proxy_cookie_path / /;
                  '';
                }
                // lib.optionalAttrs (vh ? port) {
                  locations = {
                    "/" = {
                      proxyPass = "http://127.0.0.1:${toString vh.port}/";
                      # recommendedProxySettings clears the Connection header (`proxy_set_header
                      # Connection "";`), which breaks WebSocket upgrades. Backends that use them
                      # (e.g. Immich's real-time updates) opt in via `websockets = true;` on their
                      # `virtual-host` record — nginx's standard websocket idiom (see
                      # https://nginx.org/en/docs/http/websocket.html), which sends `Connection:
                      # close` instead of keep-alive for non-Upgrade requests on that host. Fine
                      # here: upstream is always 127.0.0.1, so the lost keep-alive just costs an
                      # extra loopback handshake, not a real round trip.
                      proxyWebsockets = vh.websockets or false;
                      extraConfig = lib.optionalString (vh.protected or false) ''
                        auth_request /outpost.goauthentik.io/auth/nginx;
                        error_page 401 = @goauthentik_proxy_signin;

                        auth_request_set $auth_cookie $upstream_http_set_cookie;
                        add_header Set-Cookie $auth_cookie;
                        ${securityHeaders}

                        auth_request_set $authentik_username $upstream_http_x_authentik_username;
                        auth_request_set $authentik_groups $upstream_http_x_authentik_groups;
                        auth_request_set $authentik_email $upstream_http_x_authentik_email;
                        auth_request_set $authentik_name $upstream_http_x_authentik_name;
                        auth_request_set $authentik_uid $upstream_http_x_authentik_uid;

                        proxy_set_header X-authentik-username $authentik_username;
                        proxy_set_header X-authentik-groups $authentik_groups;
                        proxy_set_header X-authentik-email $authentik_email;
                        proxy_set_header X-authentik-name $authentik_name;
                        proxy_set_header X-authentik-uid $authentik_uid;
                      '';
                    };
                  }
                  // lib.optionalAttrs (vh.protected or false) (
                    lib.listToAttrs (
                      map (
                        path:
                        lib.nameValuePair "~ ${path}" {
                          # No URI on proxyPass: regex locations can't auto-rewrite the matched path, so this
                          # forwards the original path+query untouched, without the auth_request config below.
                          proxyPass = "http://127.0.0.1:${toString vh.port}";
                        }
                      ) (vh.bypassAuthPaths or [ ])
                    )
                  )
                  // lib.optionalAttrs (vh.protected or false) {
                    "@goauthentik_proxy_signin" = {
                      extraConfig = ''
                        internal;
                        add_header Set-Cookie $auth_cookie;
                        ${securityHeaders}
                        return 302 "https://${authentikHost}/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri";
                      '';
                    };
                    "/outpost.goauthentik.io" = {
                      proxyPass = "${authentikOutpost}/outpost.goauthentik.io";
                      extraConfig = ''
                        proxy_set_header Host $host;
                        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
                        add_header Set-Cookie $auth_cookie;
                        ${securityHeaders}
                        auth_request_set $auth_cookie $upstream_http_set_cookie;
                        proxy_pass_request_body off;
                        proxy_set_header Content-Length "";
                      '';
                    };
                  };
                }
              )
            ) virtual-host
          );

          appendHttpConfig = ''
            # Add HSTS header with preloading to HTTPS requests.
            # Adding this header to HTTP requests is discouraged
            map $scheme $hsts_header {
              https   "max-age=31536000; includeSubdomains; preload";
            }
            add_header Strict-Transport-Security $hsts_header;

            # Enable CSP for your services.
            #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

            # Minimize information leaked to other domains
            add_header 'Referrer-Policy' 'origin-when-cross-origin';

            # Disable embedding as a frame
            add_header X-Frame-Options DENY;

            # Prevent injection of code in other mime types (XSS Attacks)
            add_header X-Content-Type-Options nosniff;

            # This might create errors
            proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          '';
        };

        # Open firewall ports for HTTP and HTTPS
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
      };
  };
}
