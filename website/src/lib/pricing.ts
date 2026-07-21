/**
 * InstaLay commerce model: two storefront names, identical software.
 *
 * - InstaLay Free — same app; links out to buy a license.
 * - InstaLay — same app; you paid and supported the developer.
 *
 * Plans (one-time fee or subscription):
 *   yearly   $30 / year
 *   lifetime $100 once
 *
 * Margin floor (docs / PricingTable) uses the lifetime SKU vs Apple’s 30% cut
 * and a $20 unit COGS allocation for support, signing, CDN, payment ops.
 */

export const UNIT_COGS_USD = 20;

/** Highest store cut among Apple / Google / Microsoft. */
export const WORST_TAKE_RATE = 0.3; // Apple App Store

export const MIN_NET_FOR_100_MARGIN = UNIT_COGS_USD * 2; // $40
export const MIN_LIST_PRICE =
  MIN_NET_FOR_100_MARGIN / (1 - WORST_TAKE_RATE); // ≈ $57.14

export type MarketplaceId =
  | "apple"
  | "google"
  | "microsoft"
  | "stripe_web";

export interface Marketplace {
  id: MarketplaceId;
  name: string;
  takeRate: number;
  notes: string;
}

export const MARKETPLACES: Marketplace[] = [
  {
    id: "apple",
    name: "Apple App Store",
    takeRate: 0.3,
    notes: "Standard iOS/macOS paid-app commission (Small Business Program may be 15%).",
  },
  {
    id: "google",
    name: "Google Play",
    takeRate: 0.15,
    notes: "Typical service fee for paid apps under the current Play fee schedule.",
  },
  {
    id: "microsoft",
    name: "Microsoft Store",
    takeRate: 0.12,
    notes: "Windows Store / Partner Center revenue share.",
  },
  {
    id: "stripe_web",
    name: "Direct web (Stripe)",
    takeRate: 0.029,
    notes: "Approx. 2.9% + $0.30; model uses 2.9% only for margin comparison.",
  },
];

export function netProceeds(
  listPrice: number,
  takeRate: number,
  stripeFlat = 0,
): number {
  return listPrice * (1 - takeRate) - stripeFlat;
}

export function profitMargin(net: number, cogs = UNIT_COGS_USD): number {
  return (net - cogs) / cogs;
}

export function marketplaceRows(listPrice: number) {
  return MARKETPLACES.map((m) => {
    const flat = m.id === "stripe_web" ? 0.3 : 0;
    const net = netProceeds(listPrice, m.takeRate, flat);
    const margin = profitMargin(net);
    return {
      ...m,
      listPrice,
      net: round2(net),
      marginPct: round2(margin * 100),
      meetsTarget: margin >= 1,
    };
  });
}

export function assertPricingFloor(listPrice: number): void {
  if (listPrice + 1e-9 < MIN_LIST_PRICE) {
    throw new Error(
      `List price $${listPrice} is below Apple-floor $${round2(MIN_LIST_PRICE)} for 100% margin`,
    );
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Storefront edition names — same binary, different purchase relationship. */
export const EDITIONS = {
  free: {
    name: "InstaLay Free",
    sku: "instalay-free",
    summary:
      "Full InstaLay. Same app as InstaLay — with a link if you want to support the developer.",
  },
  paid: {
    name: "InstaLay",
    sku: "instalay",
    summary:
      "It's InstaLay, but you bought it and supported the developer.",
  },
} as const;

export type PlanId = "yearly" | "lifetime";

export interface LicensePlan {
  id: PlanId;
  name: string;
  sku: string;
  priceUsd: number;
  /** Stripe Checkout mode */
  mode: "subscription" | "payment";
  /** Human interval label, or null for one-time */
  intervalLabel: string | null;
  summary: string;
}

export const LICENSE_PLANS: Record<PlanId, LicensePlan> = {
  yearly: {
    id: "yearly",
    name: "InstaLay — Yearly",
    sku: "instalay-yearly",
    priceUsd: 30,
    mode: "subscription",
    intervalLabel: "year",
    summary: "Support the developer with a yearly license. Same app as Free.",
  },
  lifetime: {
    id: "lifetime",
    name: "InstaLay — Lifetime",
    sku: "instalay-lifetime",
    priceUsd: 100,
    mode: "payment",
    intervalLabel: null,
    summary: "One payment. Same app as Free — you own the license forever.",
  },
};

/** @deprecated Prefer LICENSE_PLANS.lifetime — kept for call sites that want “the paid product”. */
export const LICENSE_PRODUCT = {
  name: EDITIONS.paid.name,
  sku: LICENSE_PLANS.lifetime.sku,
  summary: EDITIONS.paid.summary,
  priceUsd: LICENSE_PLANS.lifetime.priceUsd,
} as const;

/** Default list price for margin tables = lifetime. */
export const LIST_PRICE_USD = LICENSE_PLANS.lifetime.priceUsd;

export const YEARLY_PRICE_USD = LICENSE_PLANS.yearly.priceUsd;
export const LIFETIME_PRICE_USD = LICENSE_PLANS.lifetime.priceUsd;

assertPricingFloor(LIFETIME_PRICE_USD);
