# aws-pgbouncer-sidecar

`aws-pgbouncer-sidecar` acts as a proxy for non-AWS-aware applications to transparently access an RDS PostgreSQL database using token authentication. It is built with Nix and uses [devenv](https://devenv.sh/) for a development shell. This project is ideal for running as a sidecar in a Kubernetes pod.

---

## Features

• Generates an AWS RDS authentication token on startup.  
• Writes a dynamic PgBouncer configuration file including the token obtained.  
• Monitors the PgBouncer process and gracefully handles reloads and shutdown signals.  
• Packaged as a container image using Nix, with support for running in development via `devenv`.

---

## Getting Started

### Prerequisites

• Nix and Flakes enabled  
• Docker/Podman (or Kubernetes) to run the container image

### Local Development with devenv and direnv

This repository uses a Nix-based development environment which is defined in `flake.nix` and `devenv.nix`. When you change into the repository directory, `direnv` automatically loads the environment variables specified in `devenv.nix` (via an associated `.envrc` file, if you have set one up).

1. Make sure you have [direnv](https://direnv.net/) installed and configured in your shell.
2. When you `cd` into the repository directory, direnv will detect the configuration and load environment variables such as:
   - `RDS_HOST`: Your AWS RDS endpoint.
   - `AWS_REGION`: AWS region (e.g., “us-east-1”).
   - `DB_USERNAME`, `DB_NAME`, and other database parameters.
3. If not using `direnv` for automatic activation, run:
   
   ```$ nix develop --no-pure-eval```

This will drop you into a shell with `aws-pgbouncer` in your `PATH` and test environment variables set from `devenv.nix`. 

---

## Usage

This project is designed to be run either locally (via the development shell) or as a container. The core script (`aws-pgbouncer.sh`) performs the following tasks:
  
1. Retrieves an authentication token for RDS using:
  
   ```aws rds generate-db-auth-token --hostname "$RDS_HOST" --port "$DB_PORT" --region "$AWS_REGION" --username "$DB_USERNAME"```
  
2. Writes the PgBouncer configuration (including the auth token) to the proper directory.
3. Starts the PgBouncer daemon, and continuously monitors it.
4. Handles SIGHUP (to reload) and SIGTERM/SIGINT for graceful shutdown.

### Running Locally

If you want to run the script directly in your development environment:

1. Ensure that the required environment variables are set (they will automatically load via `direnv` if `devenv` is set up correctly).
2. Run the script:
   
   ```$ nix run .#aws-pgbouncer```

The script will try to use AWS credentials from the environment to generate a token, and then use that in concert with the other environment variables to render a configuration file and run PgBouncer.

---

## Kubernetes Sidecar Example

You can run AWS PgBouncer as a sidecar container in a Kubernetes pod. This setup allows your main application container to connect to the PostgreSQL database via PgBouncer, with AWS RDS token authentication seamlessly integrated. 

The below assumes you have followed the guidance in [this blog post](https://aws.amazon.com/blogs/database/using-iam-authentication-to-connect-with-pgadmin-amazon-aurora-postgresql-or-amazon-rds-for-postgresql/) to set up an RDS instance capable of IAM authentication, including the creation of a database user, role, and policy that can access the database. Additionally, the role should be configured with a trust relationship allowing the use of IRSA as described [here](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).

First, create a `ServiceAccount` annotated to use the role described above:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-pgbouncer-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-irsa-role
```

Then, create a pod using the service account. Below is an example Kubernetes pod definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app-with-pgbouncer
spec:
  serviceAccountName: aws-pgbouncer-sa
  initContainers:
    - name: aws-pgbouncer
      image: ghcr.io/devusb/aws-pgbouncer:latest
      restartPolicy: Always
      env:
        - name: RDS_HOST
          value: "your-rds-instance.rds.amazonaws.com"
        - name: AWS_REGION
          value: "us-east-1"
        - name: DB_USERNAME
          value: "your_db_username"
        - name: DB_NAME
          value: "your_db_name"
        - name: DB_PORT
          value: "5432"
      ports:
        - containerPort: 5432
      livenessProbe:
        exec:
          command:
            - /bin/sh
            - -c
            - "psql -h localhost -p 5432 -U $DB_USERNAME -d $DB_NAME -c 'SELECT 1'"
        initialDelaySeconds: 10
        periodSeconds: 30
  containers:
    - name: my-application
      image: my-application:latest
      env:
        - name: DATABASE_HOST
          value: "localhost"
        - name: DATABASE_PORT
          value: "5432"
        - name: DATABASE_NAME
          value: "your_db_name"
        - name: DATABASE_USER
          value: "app_admin"
```

The `my-application` container will then be able to access the database by connecting to `localhost` on port `5432`, using the username `app_admin` to access the databased defined in `$DB_NAME`.

### How It Works in Kubernetes

1. **Token Auth with RDS:**  
   The sidecar container fetches an AWS RDS authentication token using the AWS CLI command embedded in the script. This ensures that connections to your RDS instance are authenticated using temporary tokens.

2. **Dynamic PgBouncer Configuration:**  
   After obtaining the token, the container writes the PgBouncer configuration dynamically so that user credentials include the active token. The configuration entry for your database looks similar to:

```
   [databases]  
   your_db_name = host=your-rds-instance.rds.amazonaws.com port=5432 dbname=your_db_name user=your_db_username password=<generated_token>
```

3. **localhost Proxy:**  
   Because both containers share the same network namespace in the pod, your application can connect to PgBouncer at localhost (or the designated container IP on a shared network) to access the database, while PgBouncer handles the secure connection to the RDS instance.

Once the session is established, PgBouncer should hold it open until `server_lifetime` is reached, allowing the application container to connect without knowledge of AWS or the authentication scheme.

---

## Building With Nix

This repository is structured as a Nix flake. The container image is built using `container.nix`, and the shell application is defined in `script.nix`. To build the container image locally, you can run:

```$ nix build .#packages.x86_64-linux.aws-pgbouncer-sidecar```

---

## License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE) for details.
