#!/bin/bash

set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_SUFFIX="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH_SUFFIX="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "Detected architecture: $ARCH (using $ARCH_SUFFIX for packages)"

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
    wget "https://github.com/helmfile/helmfile/releases/download/v0.168.0/helmfile_0.168.0_linux_${ARCH_SUFFIX}.tar.gz"
    tar -zxvf "helmfile_0.168.0_linux_${ARCH_SUFFIX}.tar.gz"
    mv helmfile /usr/local/bin/
    chmod +x /usr/local/bin/helmfile
    helmfile --version
else
    echo "Helmfile is already installed."
fi

# Install Kubectl
if ! [ -x "$(command -v kubectl)" ]; then
    echo "Kubectl is not installed. Installing Kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH_SUFFIX}/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    kubectl version --client
else
    echo "Kubectl is already installed."
fi

# Install Kind
if ! [ -x "$(command -v kind)" ]; then
    echo "Kind is not installed. Installing Kind..."
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/latest/kind-linux-${ARCH_SUFFIX}"
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    kind --version
else
    echo "Kind is already installed."
fi

# Install k9s
if ! command -v k9s >/dev/null; then
    echo "k9s is not installed. Installing k9s..."
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    wget "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH_SUFFIX}.tar.gz"
    tar -zxvf "k9s_Linux_${ARCH_SUFFIX}.tar.gz"
    mv k9s /usr/local/bin/
    chmod +x /usr/local/bin/k9s
    k9s version
    rm "k9s_Linux_${ARCH_SUFFIX}.tar.gz"
else
    echo "k9s is already installed."
fi

if [[ "$CUSTOM_DOMAIN" == "local.test" ]]; then
    # Set up local name resolution
    HOSTS_ENTRIES=(
    "127.0.0.1 minio-api.local.test"
    "127.0.0.1 fusion.local.test"
    "127.0.0.1 home.local.test"
    "127.0.0.1 nifi.local.test"
    "127.0.0.1 kibana.local.test"
    "127.0.0.1 wss.local.test"
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
fi

# Octostar-singlenode deployment
if [ ! -f "$GIT_DEST/k8s/local-env.yaml" ]; then
    echo "Setting up Octostar-singlenode..."
    cp "$GIT_DEST/k8s/local-env.template.yaml" "$GIT_DEST/k8s/local-env.yaml"
    sed -i "s/token: \"\"/token: \"$DOCKERHUB_TOKEN\"/" "$GIT_DEST/k8s/local-env.yaml"

    if [[ "$CUSTOM_DOMAIN" != "local.test" ]]; then
        sed -i "/^# octostar:/,/^# *domain:/{ s/^# //; }" "$GIT_DEST/k8s/local-env.yaml"
        sed -i "s/domain: \"local\.test\"/domain: \"$CUSTOM_DOMAIN\"/" "$GIT_DEST/k8s/local-env.yaml"
    fi
else
    echo "$GIT_DEST/k8s/local-env.yaml already exists."
fi

cd "$GIT_DEST"
if is_kind_cluster_running; then
    echo "Kind cluster is already running."
else
    echo "Kind cluster is not running. Executing onetime-setup.kind..."
    cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  - |
    kind: KubeletConfiguration
    apiVersion: kubelet.config.k8s.io/v1beta1
    v: 4  # Set log verbosity level to 4 for debugging
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
fi
yes yes | ./k8s/install-octostar.kind

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
    echo "$ip_address kibana.local.test"
    echo "$ip_address wss.local.test"
fi

