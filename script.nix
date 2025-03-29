{
  lib,
  writeShellApplication,
  coreutils,
  procps,
  awscli2,
  pgbouncer,
}:
writeShellApplication {
  name = "aws-pgbouncer";

  runtimeInputs = [
    coreutils
    procps
    awscli2
    pgbouncer
  ];

  text = lib.readFile ./aws-pgbouncer.sh;
}
