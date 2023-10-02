#!/bin/bash
set -e
set -o pipefail

# Colors & formatting
PURPLE=$'\033[0;35m'
RED=$'\033[0;31m'
BROWN_ORANGE=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color
SEPARATOR="------------------------------------------------------------"

# Function to display usage
usage() {
    printf "Usage: %s <REMOTE_USER_HOST> <PASSWORD> <SERVICE_NAME> <LOCAL_JAR_PATH>\n" "$0"
    printf "\n"
    printf "Arguments:\n"
    printf "  REMOTE_USER_HOST   Remote user and host in the format user@host\n"
    printf "  PASSWORD           Password for the remote user\n"
    printf "  SERVICE_NAME       Service name\n"
    printf "  LOCAL_JAR_PATH     Local path to the jar file to be deployed\n"
    exit 1
}

# Check if the required number of arguments is provided
if [ $# -ne 4 ]; then
    usage
fi

# Read command-line arguments
REMOTE_USER_HOST=$1
PASSWORD=$2
SERVICE_NAME=$3
LOCAL_JAR_PATH=$4

# Validate the provided command-line arguments
if [[ ! "$REMOTE_USER_HOST" =~ ^[a-zA-Z0-9._%+-]+@(([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|([0-9]{1,3}(\.[0-9]{1,3}){3}))$ ]]; then
    printf "%s\n" $SEPARATOR
    printf "${RED}Error:${NC} Invalid remote user and host format.\n"
    printf "%s\n" $SEPARATOR
    usage
fi

if [[ ! "$SERVICE_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    printf "%s\n" $SEPARATOR
    printf "${RED}Error:${NC} Invalid service name format.\n"
    printf "%s\n" $SEPARATOR
    usage
fi

if [ ! -f "$LOCAL_JAR_PATH" ] || [ ! -r "$LOCAL_JAR_PATH" ]; then
    printf "%s\n" $SEPARATOR
    printf "${RED}Error:${NC} Local jar file not found or not readable.\n"
    printf "%s\n" $SEPARATOR
    usage
fi

# Set paths using the provided service name
REMOTE_SERVICE_SCRIPT_PATH="/usr/local/bin/$SERVICE_NAME.sh"
REMOTE_DEPLOY_PATH="/usr/local/$SERVICE_NAME/$SERVICE_NAME.jar"
BACKUP_PATH="/u01/backup/$SERVICE_NAME/$SERVICE_NAME-$(date +"%Y-%m-%dT%H%M%S%:z").jar"

# Function to execute a single remote sudo command and handle errors
execute_remote_sudo() {
    local action_message=$1
    local command=$2
    local error_message=$3

    printf "%s\n" $SEPARATOR
    printf "${PURPLE}%s${NC}\n\n" "$action_message"
    printf "${BROWN_ORANGE}Executing:${NC}\n%s\n\n" "$command"

    if ! plink -batch -pw "$PASSWORD" "$REMOTE_USER_HOST" "echo \"$PASSWORD\" | sudo -S bash -c \"$command\""; then
        printf "%s\n" $SEPARATOR
        printf "${RED}Error:${NC} %s\n" "$error_message"
        printf "%s\n" $SEPARATOR
        return 1
    fi

    printf '\n'

    return 0
}

# Function to handle error and restore backup
handle_error_and_restore_backup() {
    local final_error_message=$1

    local action_message="${RED}[rollback] ${PURPLE}Replacing current deployment with backup"
    local command="sudo -S cp -a \"$BACKUP_PATH\" \"$REMOTE_DEPLOY_PATH\""
    local error_message="${RED}[rollback] ${NC}Failed to replace current deployment with backup."
    execute_remote_sudo "$action_message" "$command" "$error_message" || exit 1

    local action_message="${RED}[rollback] ${PURPLE}Starting the service on remote server"
    local command="sudo -S \"$REMOTE_SERVICE_SCRIPT_PATH\" start"
    local error_message="${RED}[rollback] ${NC}Failed to start the service on the remote server."
    execute_remote_sudo "$action_message" "$command" "$error_message" || exit 1

    printf "%s\n" $SEPARATOR
    printf "${RED}Error:${NC} %s Restored backup and started service using backup.\n" "$final_error_message"
    printf "%s\n" $SEPARATOR
    exit 1
}

# Functions for each step

stop_service() {
    local action_message=$1
    local command="sudo -S \"$REMOTE_SERVICE_SCRIPT_PATH\" stop"
    local error_message=$2
    execute_remote_sudo "$action_message" "$command" "$error_message"
}

create_backup() {
    local action_message=$1
    local command="sudo -S cp -a \"$REMOTE_DEPLOY_PATH\" \"$BACKUP_PATH\""
    local error_message=$2
    execute_remote_sudo "$action_message" "$command" "$error_message"
}

remove_current_deployment() {
    local action_message=$1
    local command="sudo -S rm \"$REMOTE_DEPLOY_PATH\" -f"
    local error_message=$2
    execute_remote_sudo "$action_message" "$command" "$error_message"
}

copy_new_deploy_file() {
    local action_message=$1
    local error_message=$2
    printf "%s\n" $SEPARATOR
    printf "${PURPLE}%s${NC}\n" "$action_message"
    if ! pscp -pw "$PASSWORD" -p "$LOCAL_JAR_PATH" "$REMOTE_USER_HOST:/home/${REMOTE_USER_HOST%@*}/"; then
        handle_error_and_restore_backup "$error_message"
    fi
}

deploy_new_file() {
    local action_message=$1
    local command="sudo -S mv \"/home/${REMOTE_USER_HOST%@*}/$(basename "$LOCAL_JAR_PATH")\" \"$REMOTE_DEPLOY_PATH\""
    local error_message=$2
    execute_remote_sudo "$action_message" "$command" "$error_message"
}

start_service() {
    local action_message=$1
    local command="sudo -S \"$REMOTE_SERVICE_SCRIPT_PATH\" start"
    local error_message=$2
    execute_remote_sudo "$action_message" "$command" "$error_message"
}

total_steps=6
current_step=0

# Step 1: Stop the service
current_step=$((current_step + 1))
step_title="[${current_step}/${total_steps}] Stopping the service on remote server"
error_message="Failed to stop the service on the remote server."
stop_service "$step_title" "$error_message"

# Step 2: Create backup of current deployment
current_step=$((current_step + 1))
step_title="[${current_step}/${total_steps}] Creating backup of current deployment"
error_message="Failed to create backup of the current deployment."
create_backup "$step_title" "$error_message"

# Step 3: Remove current deployment
current_step=$((current_step + 1))
step_title="[${current_step}/${total_steps}] Removing current deployment"
error_message="Failed to remove the current deployment."
remove_current_deployment "$step_title" "$error_message"

# Step 4: Copy new deploy file to server
current_step=$((current_step + 1))
step_title="[${current_step}/${total_steps}] Copying new deploy file to server"
error_message="Failed to copy the new deploy file to the server."
copy_new_deploy_file "$step_title"

# Step 5: Deploy the new file
current_step=$((current_step + 1))
step_title="[${current_step}/${total_steps}] Deploying the new file"
error_message="Failed to deploy the new file."
deploy_new_file "$step_title" "$error_message"

# Step 6: Start the service
current_step=$((current_step + 1))
step_title="[${current_step}/${total_steps}] Starting the service on remote server"
error_message="Failed to start the service on the remote server."
start_service "$step_title" "$error_message"

printf "%s\n" $SEPARATOR
printf "${CYAN}Deployment completed successfully!${NC}\n"
printf "%s\n" $SEPARATOR
