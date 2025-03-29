{ config, ... }:
{
  env = {
    RDS_HOST = "morgan-test-token.chdzmzdkdy5v.us-east-1.rds.amazonaws.com";
    AWS_REGION = "us-east-1";
    DB_PORT = "5432";
    DB_USERNAME = "morgantest";
    DB_NAME = "morgan";
    TMP_DIR = config.env.DEVENV_STATE;
    CONF_DIR = config.env.DEVENV_STATE;
  };
}
