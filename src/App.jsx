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
        console.log('GitHub Action triggered finally!');
      } else {
        console.error('Error triggering GitHub Action:', response.status);
      }
    } catch (error) {
      console.error('Error triggering GitHub Action:', error);
    }
  };

  return (
  <div id="root">
    <h1>Build Fastboot ROM</h1>
    <p>Fill in the required fields to build a Fastboot ROM.</p>

    <form ref={formRef} onSubmit={handleSubmit}>
      <h2>Recovery ROM Details</h2>
      <label htmlFor="url-input">Recovery ROM direct link:</label>
      <input type="url" id="url-input" value={url} onChange={(e) => setUrl(e.target.value)} required />

      <label htmlFor="rom-type-select">Select ROM type:</label>
      <select id="rom-type-select" value={romType} onChange={(e) => setRomType(e.target.value)} required>
        <option value="MIUI">MIUI</option>
        <option value="AOSP">AOSP</option>
      </select>

      <h2>Output Settings</h2>
      <label htmlFor="name-input">Output name for the zip ({romType === 'AOSP' ? 'required' : 'optional'}):</label>
      <input type="name" id="name-input" value={name} onChange={(e) => setName(e.target.value)} required={romType === 'AOSP'} />

      <button type="submit">Build Fastboot</button>
    </form>
  </div>
  );
};

export default App;
