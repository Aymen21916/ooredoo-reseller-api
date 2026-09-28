# Temporary Public Testing Setup (Cloudflare Tunnels)

This guide explains how to expose the local Vite frontend and Express backend to the internet for testing on external devices (like a mobile phone over cellular). Quick tunnels are temporary and will generate new URLs upon restart.

### 1. Prerequisites & Project Configuration
* **Install Cloudflared:** Run `winget install --id Cloudflare.cloudflared` (Windows) to install the tunnel CLI.
* **Update `package.json`:** In the frontend folder (`ooredoo-pos-client`), update the dev script to expose the host on your network: 
    `"dev": "vite --host"`
* **Update `vite.config.js`:** Add the following server block to prevent Vite from blocking the external tunnel URL:
    ```javascript
    export default defineConfig({
      // ...plugins
      server: { allowedHosts: true }
    })
    ```

### 2. Start Local Servers
* **Terminal 1 (Backend):** Start the API (`npm run dev` on port 3001).
* **Terminal 2 (Frontend):** Start the App (`npm run dev` on port 5173).

### 3. Expose the Backend API
* **Terminal 3:** Run `cloudflared tunnel --url http://localhost:3001`
* Copy the generated `https://[random-words].trycloudflare.com` URL. Leave this terminal open.

### 4. Connect Frontend to the New API
* In the frontend folder, open `.env.local` and paste the backend tunnel URL (appending `/api` if your routes require it):
    `VITE_API_URL=https://[backend-url].trycloudflare.com/api`
* Restart the Vite server in Terminal 2 so it picks up the new environment variable.

### 5. Expose the Frontend App
* **Terminal 4:** Run `cloudflared tunnel --url http://localhost:5173`
* Copy the newly generated `https://[random-words].trycloudflare.com` URL. This is the live address you will open on your phone. Leave this terminal open.

### 6. Allow Frontend in Backend CORS
* In the backend folder, open `.env` and update the origin variable to match your exact frontend tunnel URL (ensure there is no trailing slash at the end):
    `CORS_ORIGIN=https://[frontend-url].trycloudflare.com`
* Save the file (if using nodemon, the backend will restart automatically). 
* Open the frontend tunnel URL on your device to test the application.