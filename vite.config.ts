import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'prompt',
      includeAssets: ['pwa.svg'],
      manifest: {
        name: 'Gym Attendance and Membership Management',
        short_name: 'Gym Attendance',
        description: 'Private gym management and public member check-in.',
        theme_color: '#101827',
        background_color: '#101827',
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
