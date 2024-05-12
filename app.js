document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('fastboot-form');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const urlInput = document.getElementById('url-input');
    const romTypeSelect = document.getElementById('rom-type-select');
    const nameInput = document.getElementById('name-input');
    const githubToken = ''; // your GitHub token
    const repoOwner = 'Jefino9488';
    const repoName = 'XAGA-builder';
    const workflowId = 'Fastboot';

    const headers = {
      'Authorization': `Bearer ${githubToken}`,
      'Content-Type': 'application/json'
    };

    const data = {
      'inputs': {
        'URL': urlInput.value,
        'ROM_TYPE': romTypeSelect.value,
        'Name': nameInput.value
      }
    };

    try {
      const response = await fetch(`https://api.github.com/repos/${repoOwner}/${repoName}/actions/workflows/${workflowId}/dispatches`, {
        method: 'POST',
        headers,
        body: JSON.stringify(data)
      });

      if (response.ok) {
        console.log('GitHub Action triggered successfully!');
      } else {
        console.error('Error triggering GitHub Action:', response.status);
      }
    } catch (error) {
      console.error('Error triggering GitHub Action:', error);
    }
  });
});
