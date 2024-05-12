import { Octokit } from 'https://cdn.skypack.dev/@octokit/rest';
document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('fastboot-form');
  const urlInput = document.getElementById('url-input');
  const romTypeSelect = document.getElementById('rom-type-select');
  const nameInput = document.getElementById('name-input');

  const GITHUB_TOKEN = import.meta.env.VITE_GITHUB_TOKEN;
  const REPO_OWNER = 'Jefino9488';
  const REPO_NAME = 'XAGA-builder';
  const WORKFLOW_ID = 'FASTBOOT.yml';

  const octokit = new Octokit({
    auth: GITHUB_TOKEN
  });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    try {
      const response = await octokit.request('POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches', {
        owner: REPO_OWNER,
        repo: REPO_NAME,
        workflow_id: WORKFLOW_ID,
        ref: 'fastboot', // Add this line
        inputs: {
          URL: urlInput.value,
          ROM_TYPE: romTypeSelect.value,
          Name: nameInput.value
        }
      });

      if (response.status === 204) {
        console.log('GitHub Action triggered successfully!');
      } else {
        console.error('Error triggering GitHub Action:', response.status);
      }
    } catch (error) {
      console.error('Error triggering GitHub Action:', error);
    }
  });
});