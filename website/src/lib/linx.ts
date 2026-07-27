/** Public Linx Photos URLs — commerce + account live on linx.photos. */
export const LINX = {
  home: "https://linx.photos/",
  docs: "https://github.com/LinxPhotos/docs.linx.photos",
  /** InstaLay SKU purchase (yearly / lifetime). Append `?plan=yearly|lifetime`. */
  instalayBuy: "https://linx.photos/apps/instalay",
  /** Account page showing InstaLay subscription / lifetime ownership. */
  instalayAccount: "https://linx.photos/account/instalay",
  /**
   * Login that returns to InstaLay ownership after auth.
   * photo-service LoginForm honors `?next=` (same-origin path only).
   */
  login: "https://linx.photos/login?next=/account/instalay",
} as const;

export function linxInstalayBuyUrl(plan?: "yearly" | "lifetime"): string {
  if (!plan) return LINX.instalayBuy;
  return `${LINX.instalayBuy}?plan=${plan}`;
}
