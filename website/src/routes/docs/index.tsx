import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";

export default function DocsIndex() {
  return (
    <article class="prose">
      <Title>Docs — InstaLay</Title>
      <h1>Documentation</h1>
      <p class="lede">
        Guides for installing, framing, tapestry layouts, licensing, and store
        distribution.
      </p>
      <ul>
        <li>
          <A href="/docs/install">Install on every platform</A>
        </li>
        <li>
          <A href="/docs/pricing">InstaLay Free vs InstaLay & pricing</A>
        </li>
        <li>
          <A href="/docs/licensing">Licensing & subscriptions (Adapty)</A>
        </li>
        <li>
          <a href="https://github.com/LinxPhotos/insta-lay/blob/main/README.adoc">
            Repository README
          </a>
        </li>
        <li>
          <a href="https://github.com/LinxPhotos/insta-lay/blob/main/packaging/ms-store/README.adoc">
            Microsoft Store packaging
          </a>
        </li>
      </ul>
    </article>
  );
}
