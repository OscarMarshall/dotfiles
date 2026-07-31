{
  den.aspects.oscar.provides.work.provides.kibana.homeManager = { config, ... }: {
    age.secrets.meraki-ldap-password.rekeyFile = ../../../../../secrets/meraki-ldap-password.age;

    # Sourced by hand (`source ~/.kibana.env`) before hitting the Kibana API - `path` above is an
    # unexpanded shell snippet (e.g. Darwin's `$(getconf DARWIN_USER_TEMP_DIR)/agenix/...`), left
    # unquoted inside `cat` so the shell expands it at source time. The password itself is only
    # ever read from the decrypted secret then, so this file never carries it in plaintext.
    home.file.".kibana.env".text = ''
      export KIBANA_URL=https://kibana.ikarem.io/
      export KIBANA_USER=omarshal
      export KIBANA_PASSWORD="$(cat ${config.age.secrets.meraki-ldap-password.path})"
    '';
  };
}
