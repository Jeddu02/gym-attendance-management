import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  // Synthetic browser profiles and native database clusters are generated here.
  // Git ignores them, but Vite's filesystem watcher does not read .gitignore.
  server: {
    watch: { ignored: ['**/.cache/**'] },
    fs: {
      // fs.deny replaces Vite's defaults: retain every existing protection.
      deny: ['.env', '.env.*', '*.{crt,pem,key,p12,pfx,cer,der}', '.npmrc', '.yarnrc.yml', '**/.git/**', '**/.cache/**'],
    },
  },
  plugins: [
    react(),
    VitePWA({
      registerType: 'prompt',
      includeAssets: ['pwa.svg'],
      manifest: {
        name: 'Gym Attendance and Membership Management',
        short_name: 'Gym Attendance',
        description: 'Private gym management and public member check-in.',
        theme_color: '#0b0d14',
        background_color: '#0b0d14',
        display: 'standalone',
        icons: [
          {
            src: '/pwa.svg',
            sizes: 'any',
            type: 'image/svg+xml',
            purpose: 'any maskable',
          },
        ],
      },
    }),
  ],
});
