<!-- fullWidth: false tocVisible: false tableWrap: true -->
# Vercel Deployment Plan for dot-prompt

## Overview

Your Astro site (`dot-prompt_site/`) is configured and ready for Vercel deployment. Here's what needs to be done:

## Current Project State

- **Framework**: Astro 5.2.0
- **Output Mode**: Static (default - no server-side rendering needed)
- **Site URL**: https://prompt.so (configured in astro.config.mjs)
- **Dependencies**: Astro + Tailwind + MDX + Sitemap

---

## Deployment Steps

### Step 1: Install the Vercel Adapter

The project currently lacks the Vercel adapter. Install it using:

```bash
cd dot-prompt_site
npx astro add vercel
```

This command will:

1. Install `@astrojs/vercel` package
2. Automatically update `astro.config.mjs` to add the adapter
3. Add the adapter configuration

### Step 2: Verify astro.config.mjs After Installation

After running the command above, your config should look like:

```javascript
import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import vercel from '@astrojs/vercel';

export default defineConfig({
  site: 'https://dotprompt.run',
  base: '/',
  integrations: [
    tailwind(),
    mdx(),
    sitemap({
      changefreq: 'weekly',
      priority: 0.7,
      lastmod: new Date(),
    }),
  ],
  adapter: vercel({
    webAnalytics: { enabled: true }
  }),
  output: 'server', // or 'static' - see note below
  markdown: {
    shikiConfig: {
      wrap: true,
    },
  },
  vite: {
    css: {
      postcss: './postcss.config.cjs',
    },
  },
});
```

### Step 3: Choose Output Mode

**Option A: Static (Recommended)**\
If your site is purely static (no API routes, no SSR), keep it as static output:

```javascript
output: 'static', // default
```

Vercel will automatically detect the Astro project and handle static file serving.

**Option B: Hybrid/Server**\
If you need server-side features (API routes, SSR):

```javascript
output: 'server',
adapter: vercel(),
```

### Step 4: Deploy to Vercel

#### Option A: CLI Deployment (Quick)

```bash
cd dot-prompt_site
npm run build
npx vercel deploy --prod
```

#### Option B: Git Integration (Recommended)

1. Push your code to GitHub/GitLab/Bitbucket
2. Import the project in Vercel Dashboard
3. Configure build settings:
   - Framework Preset: Astro
   - Build Command: `npm run build`
   - Output Directory: `dist`
4. Deploy!

#### Option C: Vercel CLI (Full Deploy)

```bash
# Install Vercel CLI globally
npm i -g vercel

# Run from project root
cd dot-prompt_site
vercel
```

### Step 5: Environment Variables (If Needed)

If your site requires environment variables:

1. Go to Vercel Dashboard → Project → Settings → Environment Variables
2. Add variables matching your `.env.example` (if applicable)
3. Redeploy to apply

---

## Recommended: vercel.json Configuration

Create a `vercel.json` in `dot-prompt_site/`:

```json
{
  "framework": "astro",
  "buildCommand": "npm run build",
  "outputDirectory": "dist"
}
```

---

## Summary of Commands

```bash
# 1. Navigate to site directory
cd dot-prompt_site

# 2. Add Vercel adapter (recommended)
npx astro add vercel

# 3. Build locally (optional, to verify)
npm run build

# 4. Deploy to Vercel
npx vercel deploy --prod

# Or use Git integration (push to GitHub and import in Vercel)
```

---

## Vercel Analytics & Speed Insights

Your site is now configured with:

1. **@vercel/analytics** - For tracking page views and visitor analytics
2. **@vercel/speed-insights** - For performance monitoring

These have been added to both layouts:
- [`MarketingLayout.astro`](dot-prompt_site/src/layouts/MarketingLayout.astro)
- [`DocsLayout.astro`](dot-prompt_site/src/layouts/DocsLayout.astro)

They will automatically collect data once deployed to Vercel.

---

## Important Notes

1. **Static vs Server**: Since your current Astro config shows no server-side features, `static` output is likely sufficient
2. **Build Output**: The Astro build outputs to `dist/` directory by default
3. **Custom Domain**: Your site is configured for `https://prompt.so` - add this in Vercel after deployment
4. **No additional configuration needed** - Vercel has native Astro support!