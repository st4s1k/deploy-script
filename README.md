# Deployment Script

This Bash script automates the deployment of a JAR file to a remote server. It streamlines the process of stopping the service, creating a backup of the existing deployment, copying the new JAR file to the remote server, and restarting the service.

## Requirements
- Git for Windows (Git Bash):

    [https://gitforwindows.org/](https://gitforwindows.org/)

- PuTTY (for `pscp` and `plink`)

    [https://www.putty.org/](https://www.putty.org/)

## Usage

To use the script, execute the following command in your terminal:

```bash
./deploy.sh <REMOTE_USER_HOST> <PASSWORD> <SERVICE_NAME> <LOCAL_JAR_PATH>
```

### Arguments

- `REMOTE_USER_HOST`: The remote user and host in the format `user@host`, where the new JAR file will be deployed.
- `PASSWORD`: The password for remote user.
- `SERVICE_NAME`: The name of the service that is being deployed.
- `LOCAL_JAR_PATH`: The local path to the JAR file that you want to deploy.

## Workflow

The script performs the following steps:

1. Verifies that the required arguments are provided.
2. Validates the format of the remote user and host, the local JAR file path, and the service name.
3. Stops the service on the remote server, creates a backup of the existing JAR file, and removes the current deployment.
4. Copies the new JAR file from the local machine to the remote server.
5. Deploys the new JAR file and restarts the service on the remote server.

If any step fails, the script will attempt to restore the backup and restart the service using the backup.

## Error Handling

The script includes error handling features that provide useful messages when issues arise, such as incorrect command-line arguments or failed remote commands. Additionally, it will attempt to restore the backup and restart the service in case of failure during deployment.

## .bashrc

```bash
SSH_USERNAME="john.doe"
SSH_PASSWORD="abc123ghi789"
ENV1_HOST="10.0.0.1"
ENV2_HOST="10.0.0.2"

alias deploy="/c/Workspace/deploy-script/deploy.sh"

alias deploy-env1="deploy ${SSH_USERNAME}@${ENV1_HOST} ${SSH_PASSWORD}"
alias deploy-env2="deploy ${SSH_USERNAME}@${ENV2_HOST} ${SSH_PASSWORD}"

alias deploy-env1-service-one="deploy-env1 service-one"
alias deploy-env2-service-two="deploy-env2 service-two"
```

## DEMO
command:

```bash
/c/Workspace/deploy-script/deploy.sh john.doe@10.0.0.1 "abc123ghi789" service-one /c/Workspace/SomeProject/target/service-one-1.0.0-SNAPSHOT-r7ec8126d41f283cf271106b87f5c8a22e3a36a5c-t20230419-141346.jar
```

or

```bash
deploy john.doe@10.0.0.1 "abc123ghi789" service-one /c/Workspace/SomeProject/target/service-one-1.0.0-SNAPSHOT-r7ec8126d41f283cf271106b87f5c8a22e3a36a5c-t20230419-141346.jar
```

or

```bash
deploy-env1 service-one /c/Workspace/SomeProject/target/service-one-1.0.0-SNAPSHOT-r7ec8126d41f283cf271106b87f5c8a22e3a36a5c-t20230419-141346.jar
```

or

```bash
deploy-env1-service-one /c/Workspace/SomeProject/target/service-one-1.0.0-SNAPSHOT-r7ec8126d41f283cf271106b87f5c8a22e3a36a5c-t20230419-141346.jar
```
