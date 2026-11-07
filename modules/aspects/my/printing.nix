# Printing: CUPS plus avahi's mDNS resolver, so network printers advertised over Bonjour/IPP
# Everywhere are discovered and resolvable without a manual queue.
{
  my.printing = {
    nixos.services = {
      avahi = {
        enable = true;
        nssmdns4 = true;
      };

      printing.enable = true;
    };

    # Configured printers. `preserve` (modules/aspects/my/preserve.nix) is inert without
    # my.preservation.
    preserve.directories = [ "/var/lib/cups" ];
  };
}
