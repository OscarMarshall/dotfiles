{
  my.nginx = {
    nixos =
      {
        host,
        lib,
        virtual-host,
        ...
      }:
      let
        domain = "silverlight-nex.us";

        # Address of Authentik's embedded outpost, used to gate `protected` virtual hosts behind
        # forward-auth. Matches the address authentik-nix's own nginx integration proxies to.
        authentikOutpost = "https://127.0.0.1:9443";

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
        # Open firewall ports for HTTP and HTTPS
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
        security.acme = {
          acceptTerms = true;
          defaults.email = "letsencrypt@alias.oscarmarshall.com";
        };
        services.nginx = {
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
          enable = true;
          recommendedBrotliSettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;
          # nginx's default bucket size can't fit our longest server_name once enough
          # <service>.<host>.<domain> vhosts pile up (e.g. bookshelf-audiobooks.harmony.…, 47
          # chars) - it then refuses to start at all ("could not build server_names_hash, you
          # should increase server_names_hash_bucket_size"). 128 leaves headroom for future
          # services without revisiting this.
          serverNamesHashBucketSize = 128;
          # Exposes /nginx_status on localhost for Netdata's nginx collector (request/connection
          # metrics).
          statusPage = true;
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
                global-url = "${vh.name}.${domain}";
              in
              lib.nameValuePair url (
                {
                  enableACME = true;
                  # appendHttpConfig's proxy_cookie_path rewrite appends its own secure/HttpOnly/
                  # SameSite flags to every Set-Cookie header, even ones a backend already set its
                  # own correct flags on. That produces a Set-Cookie with duplicated attributes,
                  # which browsers can silently refuse to store — breaking login for any backend
                  # that manages its own cookie security (e.g. Immich). Opt out per host via
                  # `preserveCookieFlags = true;` on the `virtual-host` record.
                  extraConfig = lib.optionalString (vh.preserveCookieFlags or false) ''
                    proxy_cookie_path / /;
                  '';
                  forceSSL = true;
                  # Skips adding `global-url` when a service's own `url` override (e.g.
                  # authentik.nix's, when `global`) already IS the canonical name - the usual case
                  # is `url` staying host-scoped, with `global-url` merely an alias alongside it.
                  serverAliases = lib.optionals (vh.global or false && url != global-url) [ global-url ];
                }
                // lib.optionalAttrs (vh ? port) {
                  locations = {
                    "/" = {
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
                      # No trailing URI here (deliberately, like the regex bypassAuthPaths
                      # locations below): with one, nginx has to decode+re-merge the request URI to
                      # splice it onto the backend path, and an encoded slash anywhere in it (e.g.
                      # Collabora's WOPI websocket path, which embeds a full url-encoded WOPISrc
                      # URL) trips that merge and nginx 400s the request before it ever reaches the
                      # backend - confirmed by bisecting: `/foo%2Fbar` 400s, `/foo` doesn't, on this
                      # exact location. Omitting the URI makes nginx forward $request_uri verbatim,
                      # which every location here is "/" (matches the whole path) so this is a
                      # no-op for every other backend already relying on the old behavior.
                      proxyPass = "http://127.0.0.1:${toString vh.port}";
                      # recommendedProxySettings clears the Connection header (`proxy_set_header
                      # Connection "";`), which breaks WebSocket upgrades. Backends that use them
                      # (e.g. Immich's real-time updates) opt in via `websockets = true;` on their
                      # `virtual-host` record — nginx's standard websocket idiom (see
                      # https://nginx.org/en/docs/http/websocket.html), which sends `Connection:
                      # close` instead of keep-alive for non-Upgrade requests on that host. Fine
                      # here: upstream is always 127.0.0.1, so the lost keep-alive just costs an
                      # extra loopback handshake, not a real round trip.
                      proxyWebsockets = vh.websockets or false;
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
                    "/outpost.goauthentik.io" = {
                      extraConfig = ''
                        # No explicit `proxy_set_header Host` here: recommendedProxySettings
                        # already adds one (any location with proxyPass gets it) and nginx doesn't
                        # deduplicate repeated proxy_set_header lines for the same name — an
                        # explicit second one here sent the upstream a request with two literal
                        # `Host:` header lines. Go's net/http (Authentik's outpost server) rejects
                        # that outright with a bare 400 before any application code runs, which is
                        # why it never showed up in Authentik's own logs, even at trace level.
                        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
                        add_header Set-Cookie $auth_cookie;
                        ${securityHeaders}
                        auth_request_set $auth_cookie $upstream_http_set_cookie;
                        proxy_pass_request_body off;
                        proxy_set_header Content-Length "";
                      '';
                      proxyPass = "${authentikOutpost}/outpost.goauthentik.io";
                    };
                    "@goauthentik_proxy_signin" = {
                      extraConfig = ''
                        internal;
                        add_header Set-Cookie $auth_cookie;
                        ${securityHeaders}
                        # Authentik's own forward-auth (single application) docs redirect back to
                        # the CURRENT app's own domain, not Authentik's - every protected vhost
                        # already has its own "/outpost.goauthentik.io" location (below) proxying
                        # to the same embedded outpost, so $http_host lands back on a domain the
                        # outpost can actually match to this provider. Redirecting to Authentik's
                        # own domain instead landed on "Not Found", since that domain has no
                        # per-provider Host-header context for the outpost to key off of.
                        return 302 "https://$http_host/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri";
                      '';
                    };
                  };
                }
              )
            ) virtual-host
          );
        };
      };
    port-forward = [
      {
        name = "http";
        port = 80;
      }
      {
        name = "https";
        port = 443;
      }
    ];
  };
}
