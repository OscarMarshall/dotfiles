# Fingerprint reader via fprintd. nixos-hardware's Framework modules already enable it on hosts
# whose model has a reader; declaring it here as well keeps the aspect meaningful on its own.
{
  my.fingerprint = {
    nixos.services.fprintd.enable = true;
    # Enrolled fingerprints. `preserve` (modules/aspects/my/preserve.nix) is inert without
    # my.preservation.
    preserve.directories = [ "/var/lib/fprint" ];
  };
}
