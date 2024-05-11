import { Octokit } from "https://esm.sh/octokit?dts";

        const repoOwner = 'Jefino9488';
        const repoName = 'XAGA-builder';
        const workflowId = 'FASTBOOT.yml';
        const form = document.getElementById('fastboot-form');
        const octokit = new Octokit({
            auth: process.env.TOKEN,
        });

        console.log('Token:', process.env.TOKEN);

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const urlInput = document.getElementById('url-input');
            const romTypeSelect = document.getElementById('rom-type-select');
            const nameInput = document.getElementById('name-input');

            try {
                const response = await octokit.request('POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches', {
                    owner: repoOwner,
                    repo: repoName,
                    workflow_id: workflowId,
                    ref: 'fastboot',
                    inputs: {
                        URL: urlInput.value,
                        ROM_TYPE: romTypeSelect.value,
                        Name: nameInput.value
                    },
                    headers: {
                        'X-GitHub-Api-Version': '2022-11-28'
                    }
                });

                if (response.status === 200 || response.status === 201) {
                    console.log('GitHub Action triggered successfully!');
                } else {
                    console.error('Error triggering GitHub Action:', response.status);
                }
            } catch (error) {
                console.error('Error triggering GitHub Action:', error);
            }
        });