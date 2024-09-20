import { useState, useRef } from 'react';
import './App.css';
import { Octokit } from "https://esm.sh/@octokit/core";

const App = () => {
  const [buildType, setBuildType] = useState('fastboot');
  const [url, setUrl] = useState('');
  const [romType, setRomType] = useState('');
  const [name, setName] = useState('');
  const [region, setRegion] = useState('Global');
  const [corePatch, setCorePatch] = useState('false');

  const formRef = useRef(null);
  const GITHUB_TOKEN = import.meta.env.VITE_GITHUB_TOKEN;
  const REPO_OWNER = 'Jefino9488';
  const REPO_NAME = 'XAGA-builder';
  const FASTBOOT_WORKFLOW_ID = 'FASTBOOT.yml';
  const HYPER_BUILDER = 'deploy.yml';

  const octokit = new Octokit({
    auth: GITHUB_TOKEN
  });

  const handleSubmit = async (e) => {
    e.preventDefault();

    let workflow_id = buildType === 'hypermod' ? HYPER_BUILDER : FASTBOOT_WORKFLOW_ID;
    let inputs = buildType === 'hypermod'
      ? { URL: url, region, core: corePatch }
      : { URL: url, ROM_TYPE: romType, Name: name };

    try {
      const response = await octokit.request('POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches', {
        owner: REPO_OWNER,
        repo: REPO_NAME,
        workflow_id: workflow_id,
        ref: buildType === 'hypermod' ? 'hypermod' : 'fastboot',
        inputs: inputs
      });

      if (response.status === 204) {
        window.alert(`Build started for ${buildType.toUpperCase()}! Wait for 10 - 15 minutes and check the releases page.`);
        resetForm();
      } else {
        console.error('Error triggering GitHub Action:', response.status);
      }
    } catch (error) {
      console.error('Error triggering GitHub Action:', error);
    }
  };

  const resetForm = () => {
    setUrl('');
    setRomType('');
    setName('');
    setRegion('Global');
    setCorePatch('false');
  };

  const handleRedirect = () => {
    window.open('https://github.com/Jefino9488/XAGA-builder/releases', '_blank');
  };

  const handleRedirectBuild = () => {
    window.open(`https://github.com/Jefino9488/XAGA-builder/actions/workflows/${buildType === 'hypermod' ? HYPER_BUILDER : FASTBOOT_WORKFLOW_ID}`, '_blank');
  };

  return (
    <div id="root">
      <h1 id="h">Build ROM</h1>
      <br/>
      <form ref={formRef} onSubmit={handleSubmit}>

        <label htmlFor="build-type-select">Select Build Type:</label>
        <select id="build-type-select" value={buildType} onChange={(e) => setBuildType(e.target.value)} required>
          <option value="fastboot">Fastboot</option>
          <option value="hypermod">Hyper Mod</option>
        </select>

        {buildType === 'fastboot' && (
          <>
            <h2>Recovery ROM Details</h2>
            <label htmlFor="url-input">Recovery ROM direct link:</label>
            <input type="url" id="url-input" value={url} onChange={(e) => setUrl(e.target.value)} required />

            <label htmlFor="rom-type-select">Select ROM type:</label>
            <select id="rom-type-select" value={romType} onChange={(e) => setRomType(e.target.value)} required>
              <option value="">select</option>
              <option value="MIUI">MIUI</option>
              <option value="AOSP">AOSP</option>
            </select>

            <h2>Output Settings</h2>
            <label htmlFor="name-input">Output name for the zip ({romType === 'AOSP' ? 'required' : 'optional'}):</label>
            <input type="name" id="name-input" value={name} onChange={(e) => setName(e.target.value)}
                   required={romType === 'AOSP'} />
          </>
        )}

        {buildType === 'hypermod' && (
          <>
            <h2>Hyper Mod ROM Details</h2>
            <label htmlFor="url-input">Recovery ROM direct link:</label>
            <input type="url" id="url-input" value={url} onChange={(e) => setUrl(e.target.value)} required />

            <label htmlFor="region-select">Select Region:</label>
            <select id="region-select" value={region} onChange={(e) => setRegion(e.target.value)} required>
              <option value="CN">CN</option>
              <option value="Global">Global</option>
            </select>

            <label htmlFor="core-select">Apply Core Patch:</label>
            <select id="core-select" value={corePatch} onChange={(e) => setCorePatch(e.target.value)} required>
              <option value="false">No</option>
              <option value="true">Yes</option>
            </select>
          </>
        )}

        <button type="submit">Start Build</button>
      </form>

      <p>All builds are available on the releases page</p>
      <div id="root1">
        <button onClick={handleRedirect}>Go to releases</button>
        <button onClick={handleRedirectBuild}>Build Status</button>
      </div>
    </div>
  );
};

export default App;
