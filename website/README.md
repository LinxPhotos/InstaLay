# InstaLay website (SolidStart)

Static documentation + commerce shell for GitHub Pages.

```bash
pnpm install
pnpm dev
pnpm build
```

**Site URL:** https://app.linx.photos/

Also available at the project Pages hostname `https://linxphotos.github.io/insta-lay/` while DNS for the custom domain is propagating. Builds use base `/` for the apex domain.

DNS (Cloudflare → GitHub Pages):

```text
CNAME  app  linxphotos.github.io
```

Then set the Pages custom domain to `app.linx.photos` in the repo settings (or let the committed `public/CNAME` + deploy pick it up).

## Stripe (InstaLay: yearly $30 · lifetime $100)

InstaLay Free and InstaLay are the same app. Paying means you supported the developer.

1. Create Stripe Products / Payment Links:
   - **Yearly** — $30 / year (subscription Payment Link)
   - **Lifetime** — $100 one-time
2. Set `VITE_STRIPE_PAYMENT_LINK_YEARLY` and `VITE_STRIPE_PAYMENT_LINK_LIFETIME` in GitHub Actions secrets (and local `.env`).
3. Optional later: host with a server preset and enable `/api/checkout` + `/api/stripe-webhook` (`POST` body `{ "plan": "yearly" | "lifetime" }`).

Pricing copy and margin math live in `src/lib/pricing.ts`.
