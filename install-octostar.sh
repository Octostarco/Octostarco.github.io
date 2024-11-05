#!/bin/bash

set -e

GIT_DEST="/opt/octostar"
ZIP_URL="https://octostarco.github.io/octostar-singlenode.zip"
DOCKERHUB_USERNAME="octostar"

if [ -z "$DOCKERHUB_TOKEN" ]; then
    echo "Error: The environment variable DOCKERHUB_TOKEN is not set. Exiting."
    exit 1
fi

validate_domain() {
    # Check if it contains at least one dot
    if ! [[ "$CUSTOM_DOMAIN" == *.* ]]; then
        echo "Error: A valid domain name must contain at least one dot."
        exit 1
    fi
    # Check if it starts or ends with a dot
    if [[ "$CUSTOM_DOMAIN" == .* || "$CUSTOM_DOMAIN" == *. ]]; then
        echo "Error: Domain name cannot start or end with a dot."
        exit 1
    fi
    # Check if it contains only valid characters (letters, numbers, hyphens, dots)
    if ! [[ "$CUSTOM_DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$ ]]; then
        echo "Error: Domain name contains invalid characters or format."
        exit 1
    fi
}

if [ -z "$CUSTOM_DOMAIN" ]; then
    echo "Default domain 'local.test' will be used."
    CUSTOM_DOMAIN="local.test"
else
    validate_domain
fi

# Check if unzip is installed, if not, install it
if ! command -v unzip >/dev/null; then
    echo "unzip is not installed. Installing unzip..."
    sudo apt update
    sudo apt install -y unzip
else
    echo "unzip is already installed."
fi

# Download and extract the singlenode installation folder
if [ -d "$GIT_DEST" ]; then
    echo "Singlenode installation folder already exists at $GIT_DEST."
else
    echo "Downloading the singlenode installation zip and extracting to $GIT_DEST..."
    TMP_ZIP="$(mktemp --suffix=.zip)"
    curl -L "$ZIP_URL" -o "$TMP_ZIP"
    sudo mkdir -p "$GIT_DEST"
    sudo chgrp "users" "$GIT_DEST"
    sudo chmod 770 "$GIT_DEST"
    unzip "$TMP_ZIP" -d "$GIT_DEST"
    rm "$TMP_ZIP"
fi

# Octostar-singlenode deployment
if [ ! -f "$GIT_DEST/local-env.yaml" ]; then
    echo "Setting up Octostar-singlenode..."
    cp "$GIT_DEST/local-env.template.yaml" "$GIT_DEST/local-env.yaml"
    sed -i "s/token: \"\"/token: \"$DOCKERHUB_TOKEN\"/" "$GIT_DEST/local-env.yaml"

    if [[ "$CUSTOM_DOMAIN" != "local.test" ]]; then
        sed -i "/^# octostar:/,/^# *domain:/{ s/^# //; }" "$GIT_DEST/local-env.yaml"
        sed -i "s/domain: \"local\.test\"/domain: \"$CUSTOM_DOMAIN\"/" "$GIT_DEST/local-env.yaml"
    fi
else
    echo "$GIT_DEST/local-env.yaml already exists."
fi

cd "$GIT_DEST"
yes yes | ./bin/install.sh --reinstall

echo "Script execution completed!"
echo "You can now access the Octostar via home.$CUSTOM_DOMAIN in your browser."

if [[ "$CUSTOM_DOMAIN" == "local.test" ]]; then
    ip_address=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    echo
    echo
    echo "To access the Octostar from your local machine, add the following line to your /etc/hosts file:"
    echo "$ip_address home.local.test"
    echo "$ip_address minio-api.local.test"
    echo "$ip_address fusion.local.test"
    echo "$ip_address nifi.local.test"
    echo "$ip_address wss.local.test"
fi
