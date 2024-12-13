#!/bin/bash

set -e

# Check if running on Linux (Debian) or macOS
if [[ "$(uname)" == "Linux" ]]; then
    if ! command -v apt-get &> /dev/null || ! grep -qi debian /etc/os-release; then
        echo "ERROR: This script requires Debian Linux"
        exit 1
    fi

    # Install wget and unzip early as they're required for later steps
    for pkg in wget unzip; do
        if ! command -v $pkg >/dev/null; then
            echo "$pkg is not installed. Installing $pkg..."
            sudo apt update
            sudo apt install -y $pkg
        else
            echo "$pkg is already installed."
        fi
    done

elif [[ "$(uname)" == "Darwin" ]]; then
    # Check for Homebrew first
    if ! command -v brew >/dev/null; then
        echo "Homebrew is not installed. Please install Homebrew to proceed."
        exit 1
    fi

    # Install wget and unzip early as they're required for later steps
    for pkg in wget unzip; do
        if ! command -v $pkg >/dev/null; then
            echo "$pkg is not installed. Installing $pkg..."
            brew install $pkg
        else
            echo "$pkg is already installed."
        fi
    done

    :
else
    echo "ERROR: This script requires Linux (Debian) or macOS"
    exit 1
fi

GIT_DEST="/opt/octostar"
# Use stable or nightly zip based on STABLE env var
if [[ "$STABLE" == "true" ]]; then
    ZIP_URL="https://octostarco.github.io/octostar-singlenode-stable.zip"
else
    ZIP_URL="https://octostarco.github.io/octostar-singlenode.zip"
fi
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

# Download and extract the singlenode installation folder
if [ -d "$GIT_DEST" ]; then
    echo "Singlenode installation folder already exists at $GIT_DEST."
else
    echo "Downloading the singlenode installation zip and extracting to $GIT_DEST..."
    if [[ "$(uname)" == "Darwin" ]]; then
        TMP_ZIP="$(mktemp -t octostar-zip).zip"
    else
        TMP_ZIP="$(mktemp --suffix=.zip)"
    fi
    curl -L "$ZIP_URL" -o "$TMP_ZIP"
    sudo mkdir -p "$GIT_DEST"
    sudo chgrp "$(id -gn)" "$GIT_DEST"
    sudo chmod 770 "$GIT_DEST"
    unzip "$TMP_ZIP" -d "$GIT_DEST"
    rm "$TMP_ZIP"
fi

# Octostar-singlenode deployment
if [ ! -f "$GIT_DEST/local-env.yaml" ]; then
    echo "Setting up Octostar-singlenode..."
    cp "$GIT_DEST/local-env.template.yaml" "$GIT_DEST/local-env.yaml"

    if [[ "$(uname)" == "Darwin" ]]; then
        SED_INPLACE="sed -i ''"
    else
        SED_INPLACE="sed -i"
    fi

    $SED_INPLACE "s/token: \"\"/token: \"$DOCKERHUB_TOKEN\"/" "$GIT_DEST/local-env.yaml"

    if [[ "$CUSTOM_DOMAIN" != "local.test" ]]; then
        $SED_INPLACE "/^# octostar:/,/^# *domain:/{ s/^# //; }" "$GIT_DEST/local-env.yaml"
        $SED_INPLACE "s/domain: \"local\.test\"/domain: \"$CUSTOM_DOMAIN\"/" "$GIT_DEST/local-env.yaml"
    fi

    if [ -n "$SYNTHETIC_BIG_DATA" ]; then
        if [ "${SYNTHETIC_BIG_DATA,,}" = "large" ] || [ "${SYNTHETIC_BIG_DATA,,}" = "small" ]; then
            $SED_INPLACE "/^# bigData:/{ s/^# //; }" "$GIT_DEST/local-env.yaml"
            $SED_INPLACE "s/bigData: \"none\"/bigData: \"${SYNTHETIC_BIG_DATA,,}\"/" "$GIT_DEST/local-env.yaml"
        else
            echo "SYNTHETIC_BIG_DATA is set to '$SYNTHETIC_BIG_DATA' but is neither 'large' nor 'small'"
        fi
    fi

    if [[ -n "$ADMIN_PASSWORD" ]]; then
        $SED_INPLACE "s/^#*\s*timbrAdminPassword:.*/timbrAdminPassword: \"$ADMIN_PASSWORD\"/" "$GIT_DEST/local-env.yaml"
    fi

    if [[ "$ASSEMBLYAI_TOKEN" != "assemblyai_token" ]]; then
        $SED_INPLACE "s/^#*\s*assemblyAIAPIKey:.*/assemblyAIAPIKey: \"$ASSEMBLYAI_TOKEN\"/" "$GIT_DEST/local-env.yaml"
    fi

    if [[ "$ESPYSYS_TOKEN" != "espysys_token" ]]; then
        $SED_INPLACE "s/^#*\s*espysysAPIKey:.*/espysysAPIKey: \"$ESPYSYS_TOKEN\"/" "$GIT_DEST/local-env.yaml"
    fi

    if [[ "$MITO_TOKEN" != "mito_token" ]]; then
        $SED_INPLACE "s/^#*\s*mitoAPIKey:.*/mitoAPIKey: \"$MITO_TOKEN\"/" "$GIT_DEST/local-env.yaml"
    fi

    if [[ "$OPENAI_TOKEN" != "openai_token" ]]; then
        $SED_INPLACE "s/^#*\s*openaiToken:.*/openaiToken: \"$OPENAI_TOKEN\"/" "$GIT_DEST/local-env.yaml"
    fi

    if [[ "$SOCIALLINKS_TOKEN" != "sociallinks_token" ]]; then
        $SED_INPLACE "s/^#*\s*socialLinksAPIKey:.*/socialLinksAPIKey: \"$SOCIALLINKS_TOKEN\"/" "$GIT_DEST/local-env.yaml"
    fi

else
    echo "$GIT_DEST/local-env.yaml already exists."
fi

cd "$GIT_DEST"
yes yes | ./bin/install.sh --reinstall

echo "Script execution completed!"
echo "You can now access the Octostar via home.$CUSTOM_DOMAIN in your browser."

get_ip_address() {
    if [[ "$(uname)" == "Linux" ]]; then
        ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1
    elif [[ "$(uname)" == "Darwin" ]]; then
        ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
    fi
}

if [[ "$CUSTOM_DOMAIN" == "local.test" ]]; then
    ip_address=$(get_ip_address)
    echo
    echo
    echo "To access the Octostar from your local machine, add the following line to your /etc/hosts file:"
    echo "$ip_address home.local.test"
    echo "$ip_address minio-api.local.test"
    echo "$ip_address fusion.local.test"
    echo "$ip_address nifi.local.test"
    echo "$ip_address wss.local.test"
fi
