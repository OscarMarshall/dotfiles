{
  den.quirks.virtual-host.description = "Reverse-proxied virtual hosts served by nginx";

  my.nginx = {
    nixos =
      {
        virtual-host,
        lib,
        config,
        ...
      }:
      let
        # Address of Authentik's embedded outpost, used to gate `protected` virtual hosts behind
        # forward-auth. Matches the address authentik-nix's own nginx integration proxies to.
        authentikOutpost = "https://127.0.0.1:9443";
        authentikHost = config.services.authentik.nginx.host;
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

          # Only allow PFS-enabled ciphers with AES256
          sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

          virtualHosts = lib.listToAttrs (
            map (
              host:
              lib.nameValuePair host.url {
                forceSSL = true;
                enableACME = true;
                locations = {
                  "/" = {
                    proxyPass = "http://127.0.0.1:${toString host.port}/";
                    extraConfig = lib.optionalString (host.protected or false) ''
                      auth_request /outpost.goauthentik.io/auth/nginx;
                      error_page 401 = @goauthentik_proxy_signin;

                      auth_request_set $auth_cookie $upstream_http_set_cookie;
                      add_header Set-Cookie $auth_cookie;

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
                // lib.optionalAttrs (host.protected or false) {
                  "@goauthentik_proxy_signin" = {
                    extraConfig = ''
                      internal;
                      add_header Set-Cookie $auth_cookie;
                      return 302 "https://${authentikHost}/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri";
                    '';
                  };
                  "/outpost.goauthentik.io" = {
                    proxyPass = "${authentikOutpost}/outpost.goauthentik.io";
                    extraConfig = ''
                      proxy_set_header Host $host;
                      proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
                      add_header Set-Cookie $auth_cookie;
                      auth_request_set $auth_cookie $upstream_http_set_cookie;
                      proxy_pass_request_body off;
                      proxy_set_header Content-Length "";
                    '';
                  };
                };
              }
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
