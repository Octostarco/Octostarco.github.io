function updateCommand() {
    const dockerhub_token = document.getElementById('dockerhub-token').value.trim();
    const assemblyai_token = document.getElementById('assemblyai-token').value.trim();
    const espysys_token = document.getElementById('espysys-token').value.trim();
    const mito_token = document.getElementById('mito-token').value.trim();
    const openai_token = document.getElementById('openai-token').value.trim();
    const sociallinks_token = document.getElementById('sociallinks-token').value.trim();
    const domain = document.getElementById('domain-name').value.trim();
    const syntheticData = document.getElementById('synthetic-data').checked;
    const gpuPassthrough = document.getElementById('gpu-passthrough').checked;

    // Get the copy button
    const copyButton = document.querySelector('.copy-command-btn');

    // Enable/disable button based on Docker Hub token
    copyButton.disabled = !dockerhub_token;

    // Build command parts array
    const commandParts = [
        'curl https://octostarco.github.io/install-octostar.sh | env'
    ];

    if (dockerhub_token) {
        commandParts.push(`DOCKERHUB_TOKEN=${dockerhub_token}`);
    }
    if (assemblyai_token) {
        commandParts.push(`ASSEMBLYAI_TOKEN=${assemblyai_token}`);
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
    
    // Modern clipboard API
    if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(scriptText)
            .then(() => alert("Installation script copied to clipboard!"))
            .catch(err => {
                console.error('Failed to copy: ', err);
                alert("Failed to copy to clipboard. Please copy manually.");
            });
    } else {
        // Fallback for non-HTTPS or unsupported browsers
        try {
            const textArea = document.createElement("textarea");
            textArea.value = scriptText;
            textArea.style.position = "fixed";  // Avoid scrolling to bottom
            textArea.style.opacity = "0";
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            
            const successful = document.execCommand('copy');
            document.body.removeChild(textArea);
            
            if (successful) {
                alert("Installation script copied to clipboard!");
            } else {
                alert("Failed to copy to clipboard. Please copy manually.");
            }
        } catch (err) {
            console.error('Failed to copy: ', err);
            alert("Failed to copy to clipboard. Please copy manually.");
        }
    }
}

// Call once on page load to ensure proper initial state
document.addEventListener('DOMContentLoaded', updateCommand);
