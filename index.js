function updateCommand() {
    const dockerhub_token = document.getElementById('dockerhub-token').value.trim();
    const espysys_token = document.getElementById('espysys-token').value.trim() || 'espysys_token';
    const mito_token = document.getElementById('mito-token').value.trim() || 'mito_token';
    const openai_token = document.getElementById('openai-token').value.trim() || 'openai_token';
    const sociallinks_token = document.getElementById('sociallinks-token').value.trim() || 'sociallinks_token';
    const domain = document.getElementById('domain-name').value.trim();
    const syntheticData = document.getElementById('synthetic-data').checked;
    const gpuPassthrough = document.getElementById('gpu-passthrough').checked;

    // Get the copy button
    const copyButton = document.querySelector('.copy-command-btn');
    
    // Enable/disable button based on Docker Hub token
    copyButton.disabled = !dockerhub_token;
    
    // Build command parts array
    const commandParts = [
        'curl https://octostarco.github.io/install-octostar.sh | env',
        `DOCKERHUB_TOKEN=${dockerhub_token || 'dockerhub_token'}`,
        `ESPYSYS_TOKEN=${espysys_token}`,
        `MITO_TOKEN=${mito_token}`,
        `OPENAI_TOKEN=${openai_token}`,
        `SOCIALLINKS_TOKEN=${sociallinks_token}`
    ];
    
    if (domain) {
        commandParts.push(`CUSTOM_DOMAIN=${domain}`);
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