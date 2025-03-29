{
  lib,
  dockerTools,
  fakeNss,
  aws-pgbouncer,
  postgresql,
}:
dockerTools.buildLayeredImage {
  name = "ghcr.io/devusb/aws-pgbouncer";
  tag = "latest";

  contents = [
    fakeNss
    aws-pgbouncer
    postgresql # for health check
  ];

  config = {
    Cmd = [ "${lib.getExe aws-pgbouncer}" ];
    User = "nobody";
  };

  extraCommands = ''
    chmod -R 777 var/empty
    mkdir -p tmp
    chmod 777 tmp
    mkdir -p etc
    chmod 777 etc
  '';

}
