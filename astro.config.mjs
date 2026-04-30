// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

// https://astro.build/config
export default defineConfig({
  site: 'https://37design.co.jp',
  trailingSlash: 'always',
  integrations: [sitemap({
    filter: (page) =>
      !page.includes('/dashboard') &&
      !page.includes('/guide/api-keys') &&
      !page.includes('/lp/') &&
      !page.includes('/resources/') &&
      !page.includes('/tokushoho') &&
      !page.includes('/privacy'),
    serialize(item) {
      // ブログ記事は publishDate / lastModified を lastmod に反映
      const match = item.url.match(/\/blog\/([^/]+)\/?$/);
      if (match) {
        const slug = match[1];
        const post = blogLastmodMap.get(slug);
        if (post) {
          item.lastmod = post.toISOString();
        }
      }
      return item;
    },
  })],
  compressHTML: true,
  vite: {
    plugins: [tailwindcss()],
    build: {
      cssMinify: 'lightningcss',
    },
  },
});

// ブログ記事の lastmod を解決するためのマップ（ビルド時に1度だけ構築）
const blogLastmodMap = await buildBlogLastmodMap();

async function buildBlogLastmodMap() {
  const fs = await import('node:fs/promises');
  const path = await import('node:path');
  const url = await import('node:url');
  const blogDir = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), 'src/content/blog');
  const map = new Map();
  try {
    const files = await fs.readdir(blogDir);
    for (const file of files) {
      if (!file.endsWith('.md')) continue;
      const slug = file.replace(/\.md$/, '');
      const content = await fs.readFile(path.join(blogDir, file), 'utf-8');
      const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
      if (!fmMatch) continue;
      const fm = fmMatch[1];
      const lastModMatch = fm.match(/^lastModified:\s*(\S+)/m);
      const pubMatch = fm.match(/^publishDate:\s*(\S+)/m);
      const dateStr = lastModMatch?.[1] ?? pubMatch?.[1];
      if (dateStr) {
        const d = new Date(dateStr);
        if (!isNaN(d.getTime())) map.set(slug, d);
      }
    }
  } catch (e) {
    console.warn('[sitemap] blog lastmod map build failed:', e);
  }
  return map;
}
