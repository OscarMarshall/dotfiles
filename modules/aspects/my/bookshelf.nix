{ my, ... }:
{
  my.bookshelf =
    let
      port = 8787;
    in
    {
      includes = with my; [ (nginx._.virtual-host "bookshelf.harmony.silverlight-nex.us" port) ];

      nixos = {
        virtualisation.oci-containers.containers.bookshelf = {
          image = "ghcr.io/pennydreadful/bookshelf:hardcover@sha256:388eecc94362580eae31ee0a454be6af516f8a311f8432a521c202fb475f4359";
          ports =
            let
              port' = toString port;
            in
            [ "127.0.0.1:${port'}:${port'}" ];
          volumes = [ "/metalminds/bookshelf:/config" ];
        };
      };
    };
}
