# InstaLay website (SolidStart)

Static documentation + commerce shell for GitHub Pages.

```bash
pnpm install
pnpm dev
pnpm build
```

**Site URL:** https://linxphotos.github.io/InstaLay/

Builds use `GITHUB_PAGES_BASE=/InstaLay/` so Vite assets and Solid Router share the same prefix as the GitHub repo name. Without the router `base`, the SPA hydrates blank on project Pages.

When `instalay.linx.photos` DNS is ready:

1. Cloudflare: `CNAME instalay → linxphotos.github.io`
2. Set Pages custom domain in repo settings
3. Rebuild with `GITHUB_PAGES_BASE=/` and add `public/CNAME`

## Stripe

Set secrets / `.env` as in `.env.example`. Pricing lives in `src/lib/pricing.ts`.
