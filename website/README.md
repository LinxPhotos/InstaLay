# InstaLay website (SolidStart)

Static documentation + commerce shell for GitHub Pages.

```bash
pnpm install
pnpm dev
pnpm build
```

Site URL: https://ryanjohnson.dev/insta-lay/

(Also available via the repo Pages hostname depending on DNS.)

## Stripe (one-time universal license · $59.99)

1. Create a Stripe Product / Payment Link for **$59.99** one-time.
2. Set `VITE_STRIPE_PAYMENT_LINK` in GitHub Actions secrets (and local `.env`).
3. Optional later: host with a server preset and enable `/api/checkout` + `/api/stripe-webhook`.

Pricing math lives in `src/lib/pricing.ts` (100% margin vs Apple 30% floor).
