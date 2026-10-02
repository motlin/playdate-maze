import { defineConfig } from 'astro/config';

export default defineConfig({
  output: 'static',
  base: '/walkthrough-comparison',
  outDir: '../../docs/walkthrough-comparison',
  build: { inlineStylesheets: 'always' },
  devToolbar: { enabled: false },
});
