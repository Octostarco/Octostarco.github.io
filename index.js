function updateCommand() {
    const dockerhub_token = document.getElementById('dockerhub-token').value.trim() || 'dockerhub_token';
    const espysys_token = document.getElementById('espysys-token').value.trim();
    const mito_token = document.getElementById('mito-token').value.trim();
    const openai_token = document.getElementById('openai-token').value.trim();
    const sociallinks_token = document.getElementById('sociallinks-token').value.trim();
    const domain = document.getElementById('domain-name').value.trim();
    const syntheticData = document.getElementById('synthetic-data').checked;
    const gpuPassthrough = document.getElementById('gpu-passthrough').checked;

    // Build command parts array
    const commandParts = [
        'curl https://octostarco.github.io/install-octostar.sh | env',
        `DOCKERHUB_TOKEN=${dockerhub_token}`
    ];
    
    if (domain) {
        commandParts.push(`CUSTOM_DOMAIN=${domain}`);
    }

    if (espysys_token) {
        commandParts.push(`ESPYSYS_TOKEN=${espysys_token}`);
    }

    if (mito_token) {
        commandParts.push(`MITO_TOKEN=${mito_token}`);
    }

    if (openai_token) {
        commandParts.push(`OPENAI_TOKEN=${openai_token}`);
    }

    if (sociallinks_token) {
        commandParts.push(`SOCIALLINKS_TOKEN=${sociallinks_token}`);
    }

    if (syntheticData) {
        commandParts.push('SYNTHETIC_BIG_DATA=large');
    }
    
    if (gpuPassthrough) {
        commandParts.push('ENABLE_GPU=true');
    }
    
    commandParts.push('bash');
    
    // Join with single spaces and set content
    const command = commandParts.join(' ').trim();
    document.getElementById('install-script').textContent = command;
}

function copyToClipboard(elementId) {
    const scriptText = document.getElementById(elementId).innerText;
    navigator.clipboard.writeText(scriptText)
        .then(() => alert("Installation script copied to clipboard!"))
        .catch(() => {
            // Fallback for older browsers
            const tempInput = document.createElement("textarea");
            tempInput.value = scriptText;
            document.body.appendChild(tempInput);
            tempInput.select();
            document.execCommand("copy");
            document.body.removeChild(tempInput);
            alert("Installation script copied to clipboard!");
        });
}

// Call once on page load to ensure proper initial state
document.addEventListener('DOMContentLoaded', updateCommand); 