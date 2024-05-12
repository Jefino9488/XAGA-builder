import './style.css'
import javascriptLogo from './javascript.svg'
import viteLogo from '/vite.svg'
import { setupCounter } from './app.js'

document.querySelector('#app').innerHTML = `
  <div>
    <form id="fastboot-form">
        <label for="url-input">Recovery ROM direct link:</label>
        <input type="text" id="url-input" name="url-input" required>

        <label for="rom-type-select">Select ROM type:</label>
        <select id="rom-type-select" name="rom-type-select" required>
            <option value="MIUI">MIUI</option>
            <option value="AOSP">AOSP</option>
        </select>

        <label for="name-input">Output name for the zip (optional):</label>
      <input type="text" id="name-input" name="name-input">

        <button type="submit">Build Fastboot</button>
    </form>
  </div>
`

setupCounter(document.querySelector('#counter'))
