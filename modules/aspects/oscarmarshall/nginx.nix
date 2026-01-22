{
  oscarmarshall.nginx = {
    provides.virtual-host = url: port: {
      nixos.services.nginx.virtualHosts.${url} = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString port}/";
      };
    };
    nixos = {
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
