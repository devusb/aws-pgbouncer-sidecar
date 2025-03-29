{
  lib,
  dockerTools,
  fakeNss,
  aws-pgbouncer,
}:
dockerTools.buildLayeredImage {
  name = "ghcr.io/devusb/aws-pgbouncer";
  tag = "latest";

  contents = [
    fakeNss
    aws-pgbouncer
  ];

  config = {
    Cmd = [ "${lib.getExe aws-pgbouncer}" ];
    User = "nobody";
  };

  extraCommands = ''
    mkdir -p tmp
    chmod 777 tmp
    mkdir -p etc
    chmod 777 etc
  '';

}
