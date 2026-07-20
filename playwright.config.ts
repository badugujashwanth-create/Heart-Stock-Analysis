import { defineConfig } from '@playwright/test';

export default defineConfig({
  timeout: 60_000,
  retries: 0,
  use: {
    baseURL: process.env.DEMO_BASE_URL || 'http://127.0.0.1:8085',
    headless: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  reporter: [['list']],
});
