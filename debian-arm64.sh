#!/bin/bash

set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

GIT_DEST="/home/octostar"
ZIP_URL="https://octostarco.github.io/octostar-singlenode.zip"
DOCKERHUB_USERNAME="octostar"

if [ -z "$DOCKERHUB_TOKEN" ]; then
  echo "Error: The environment variable DOCKERHUB_TOKEN is not set. Exiting."
  exit 1
fi

function has_systemd() {
    if pidof systemd >/dev/null; then
        return 0  # Systemd is available
    else
        return 1  # Systemd is not available
    fi
}

function is_kind_cluster_running() {
    if kind get clusters | grep -q 'kind'; then
        return 0  # Kind cluster is running
    else
        return 1  # Kind cluster is not running
    fi
}

# Check if unzip is installed, if not, install it
if ! command -v unzip >/dev/null; then
    echo "unzip is not installed. Installing unzip..."
    apt update
    apt install -y unzip
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
    mkdir -p "$GIT_DEST"
    unzip "$TMP_ZIP" -d "$GIT_DEST"
    rm "$TMP_ZIP"
fi


# Install Docker
if ! [ -x "$(command -v docker)" ]; then
    echo "Docker is not installed. Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update

    echo "Installing Docker packages..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "Docker is already installed."
fi

# Start Docker service
if has_systemd; then
    echo "Systemd detected. Starting Docker service with systemctl..."
    systemctl start docker
    systemctl enable docker
else
    echo "Systemd not detected. Starting Docker daemon manually..."
    dockerd > /dev/null 2>&1 &
    sleep 5  # Wait for Docker daemon to start
fi

# Ensure Docker daemon is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker daemon is not running. Exiting..."
    exit 1
fi

echo "Logging into Docker Hub..."
echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin

# Install Helm
if ! [ -x "$(command -v helm)" ]; then
    echo "Helm is not installed. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
else
    echo "Helm is already installed."
fi

if ! command -v wget &> /dev/null; then
    echo "wget is not installed. Installing wget..."
    apt-get install -y wget
else
    echo "wget is already installed."
fi

# Install Helmfile
if ! [ -x "$(command -v helmfile)" ]; then
    echo "Helmfile is not installed. Installing Helmfile..."
    wget https://github.com/helmfile/helmfile/releases/download/v0.168.0/helmfile_0.168.0_linux_arm64.tar.gz
    tar -zxvf helmfile_0.168.0_linux_arm64.tar.gz
    mv helmfile /usr/local/bin/
    chmod +x /usr/local/bin/helmfile
    helmfile --version
else
    echo "Helmfile is already installed."
fi

# Install Kubectl
if ! [ -x "$(command -v kubectl)" ]; then
    echo "Kubectl is not installed. Installing Kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    kubectl version --client
else
    echo "Kubectl is already installed."
fi

# Install Kind
if ! [ -x "$(command -v kind)" ]; then
    echo "Kind is not installed. Installing Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-arm64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    kind --version
else
    echo "Kind is already installed."
fi

# Set up local name resolution
HOSTS_ENTRIES=(
"127.0.0.1 minio-api.local.test"
"127.0.0.1 fusion.local.test"
"127.0.0.1 home.local.test"
"127.0.0.1 nifi.local.test"
"127.0.0.1 kibana.local.test"
)

echo "Setting up local name resolution..."
for HOSTS_ENTRY in "${HOSTS_ENTRIES[@]}"; do
    if ! grep -Fxq "$HOSTS_ENTRY" /etc/hosts; then
        echo "$HOSTS_ENTRY" >> /etc/hosts
        echo "Added $HOSTS_ENTRY to /etc/hosts"
    else
        echo "$HOSTS_ENTRY already exists in /etc/hosts"
    fi
done

# Add self-signed root CA certificate
if [ ! -f "/usr/local/share/ca-certificates/rootCA.crt" ]; then
    echo "Adding self-signed root CA certificate..."
    cp "$GIT_DEST/k8s/rootCA.pem" /usr/local/share/ca-certificates/rootCA.crt
    update-ca-certificates
else
    echo "Root CA certificate already installed."
fi

# Octostar-singlenode deployment
if [ ! -f "$GIT_DEST/k8s/local-env.yaml" ]; then
    echo "Setting up Octostar-singlenode..."
    cp "$GIT_DEST/k8s/local-env.template.yaml" "$GIT_DEST/k8s/local-env.yaml"
    sed -i "s/token: \"\"/token: \"$DOCKERHUB_TOKEN\"/" "$GIT_DEST/k8s/local-env.yaml"
else
    echo "$GIT_DEST/k8s/local-env.yaml already exists."
fi

cd "$GIT_DEST"
if is_kind_cluster_running; then
    echo "Kind cluster is already running."
else
    echo "Kind cluster is not running. Executing onetime-setup.kind..."
    ./k8s/onetime-setup.kind
fi
yes yes | ./k8s/install-octostar.kind

echo "Script execution completed!"
echo "You can now access the Octostar via home.local.test in your browser."
