{
  den.aspects.oscar.provides.work.provides.kibana.homeManager = { config, ... }: {
    age.secrets.meraki-ldap-password.rekeyFile = ../../../../../secrets/meraki-ldap-password.age;

    # Sourced by hand (`source ~/.kibana.env`) before hitting the Kibana API - the password is
    # substituted at source time via an unquoted `$(cat ...)`, not baked into the store, so the
    # file itself never carries the secret in plaintext.
    home.file.".kibana.env".text = ''
      export KIBANA_URL=https://kibana.ikarem.io/
      export KIBANA_USER=omarshal
      export KIBANA_PASSWORD="$(cat ${config.age.secrets.meraki-ldap-password.path})"
    '';
  };
}
