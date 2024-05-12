import React, { useState, useRef } from 'react';
import './App.css';

import { Octokit } from "https://esm.sh/@octokit/core";

const App = () => {
  const [url, setUrl] = useState('');
  const [romType, setRomType] = useState('');
  const [name, setName] = useState('');
  const formRef = useRef(null);

  const GITHUB_TOKEN = import.meta.env.VITE_GITHUB_TOKEN;
  const REPO_OWNER = 'Jefino9488';
  const REPO_NAME = 'XAGA-builder';
  const WORKFLOW_ID = 'FASTBOOT.yml';

  const octokit = new Octokit({
    auth: GITHUB_TOKEN
  });

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      const response = await octokit.request('POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches', {
        owner: REPO_OWNER,
        repo: REPO_NAME,
        workflow_id: WORKFLOW_ID,
        ref: 'fastboot',
        inputs: {
          URL: url,
          ROM_TYPE: romType,
          Name: name
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
  };

  return (
    <div>
      <form ref={formRef} onSubmit={handleSubmit}>
        <label htmlFor="url-input">Recovery ROM direct link:</label>
        <input type="text" id="url-input" value={url} onChange={(e) => setUrl(e.target.value)} required />

        <label htmlFor="rom-type-select">Select ROM type:</label>
        <select id="rom-type-select" value={romType} onChange={(e) => setRomType(e.target.value)} required>
          <option value="MIUI">MIUI</option>
          <option value="AOSP">AOSP</option>
        </select>

        <label htmlFor="name-input">Output name for the zip (optional):</label>
        <input type="text" id="name-input" value={name} onChange={(e) => setName(e.target.value)} />

        <button type="submit">Build Fastboot</button>
      </form>
    </div>
  );
};

export default App;