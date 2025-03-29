{
  lib,
  writeShellApplication,
  awscli2,
  pgbouncer,
}:
writeShellApplication {
  name = "aws-pgbouncer";

  runtimeInputs = [
    awscli2
    pgbouncer
  ];

  text = lib.readFile ./aws-pgbouncer.sh;
}
