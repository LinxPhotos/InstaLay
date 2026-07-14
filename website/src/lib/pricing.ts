/**
 * Universal one-time license pricing for Insta Lay.
 *
 * Goal: ≥100% profit margin even if the least profitable marketplace
 * (Apple App Store @ 30% commission) were the only storefront.
 *
 * Margin definition used here:
 *   margin = (netProceeds - unitCogs) / unitCogs
 * where unitCogs is the allocated per-seat cost of sale (support, signing,
 * CDN, payment ops) — NOT raw COGS of digital bits.
 *
 * netProceeds = listPrice * (1 - marketplaceTakeRate)
 * For margin ≥ 1.0: listPrice >= (2 * unitCogs) / (1 - takeRate)
 */
export const UNIT_COGS_USD = 20;

/** Highest store cut among Apple / Google / Microsoft. */
export const WORST_TAKE_RATE = 0.3; // Apple App Store

export const MIN_NET_FOR_100_MARGIN = UNIT_COGS_USD * 2; // $40
export const MIN_LIST_PRICE =
  MIN_NET_FOR_100_MARGIN / (1 - WORST_TAKE_RATE); // ≈ $57.14

/** Chosen psychological price ≥ mathematical floor. */
export const LIST_PRICE_USD = 59.99;

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

export function marketplaceRows(listPrice = LIST_PRICE_USD) {
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

export function assertPricingFloor(listPrice = LIST_PRICE_USD): void {
  if (listPrice + 1e-9 < MIN_LIST_PRICE) {
    throw new Error(
      `List price $${listPrice} is below Apple-floor $${round2(MIN_LIST_PRICE)} for 100% margin`,
    );
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Product copy for the universal permanent license. */
export const LICENSE_PRODUCT = {
  name: "Insta Lay — Universal Lifetime License",
  sku: "instalay-universal-lifetime",
  summary:
    "One payment unlocks Insta Lay on Windows, macOS, Linux, Android, iOS, and web builds you run.",
  priceUsd: LIST_PRICE_USD,
} as const;
