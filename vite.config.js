import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The interface is built into dist/ and bundled into the native app (see native/build.sh).
export default defineConfig({ plugins: [react()] });
