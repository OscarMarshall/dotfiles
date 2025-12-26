{config, ...}: {
  services.nginx = {
    enable = true;

    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";

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

    virtualHosts = let
      base = locations: {
        inherit locations;

        forceSSL = true;
        enableACME = true;
      };
      proxy = port:
        base {
          "/".proxyPass = "http://127.0.0.1:${toString port}/";
        };
    in {
      "harmony.silverlight-nex.us" = proxy 8082;
      "autobrr.harmony.silverlight-nex.us" = proxy config.services.autobrr.settings.port;
      "plex.harmony.silverlight-nex.us" = proxy 32400;
      "profilarr.harmony.silverlight-nex.us" = proxy 6868;
      "prowlarr.harmony.silverlight-nex.us" = proxy config.services.prowlarr.settings.server.port;
      "qbittorrent.harmony.silverlight-nex.us" = proxy 8080;
      "radarr.harmony.silverlight-nex.us" = proxy config.services.radarr.settings.server.port;
      "sonarr.harmony.silverlight-nex.us" = proxy config.services.sonarr.settings.server.port;
    };
  };
}
