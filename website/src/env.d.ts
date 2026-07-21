/// <reference types="vinxi/types/client" />

interface ImportMetaEnv {
  readonly VITE_STRIPE_PAYMENT_LINK_YEARLY?: string;
  readonly VITE_STRIPE_PAYMENT_LINK_LIFETIME?: string;
  /** @deprecated Prefer VITE_STRIPE_PAYMENT_LINK_LIFETIME */
  readonly VITE_STRIPE_PAYMENT_LINK?: string;
  readonly VITE_STRIPE_BUY_BUTTON_URL?: string;
  readonly VITE_STRIPE_PUBLISHABLE_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
