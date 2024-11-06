function updateCommand() {
    const token = document.getElementById('dockerhub-token').value.trim() || 'dockerhub_token';
    const domain = document.getElementById('domain-name').value.trim();
    const syntheticData = document.getElementById('synthetic-data').checked;
    const gpuPassthrough = document.getElementById('gpu-passthrough').checked;

    // Build command parts array
    const commandParts = [
        'curl https://octostarco.github.io/install-octostar.sh | env',
        `DOCKERHUB_TOKEN=${token}`
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