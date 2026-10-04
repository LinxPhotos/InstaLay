import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { LINX } from "../../lib/linx";

export default function DocsIndex() {
  return (
    <article class="prose">
      <Title>Docs — InstaLay</Title>
      <h1>Documentation</h1>
      <p class="lede">
        Guides for downloading, framing, tapestry layouts, licensing, and store
        distribution.
      </p>
      <ul>
        <li>
          <A href="/download">Download and install</A>
        </li>
        <li>
          <a href="https://app.instalay.linx.photos" rel="noopener noreferrer">
            Web app — editor in the browser
          </a>
        </li>
        <li>
          <a
            href="https://github.com/LinxPhotos/InstaLay/blob/main/docs/WEB-APP-DEPLOY.adoc"
            rel="noopener noreferrer"
          >
            Web app hosting &amp; DNS (repository doc)
          </a>
        </li>
        <li>
          <A href="/docs/pricing">InstaLay Free vs InstaLay & pricing</A>
        </li>
        <li>
          <A href="/docs/marketplace-margin">Marketplace margin</A>
        </li>
        <li>
          <A href="/docs/licensing">Licensing & Linx entitlements</A>
        </li>
        <li>
          <a href={LINX.home} rel="noopener noreferrer">
            Linx Photos — albums, hosting &amp; scheduling
          </a>
        </li>
        <li>
          <a href="https://github.com/LinxPhotos/InstaLay/blob/main/README.adoc">
            Repository README
          </a>
        </li>
        <li>
          <a href="https://github.com/LinxPhotos/InstaLay/blob/main/packaging/ms-store/README.adoc">
            Microsoft Store packaging
          </a>
        </li>
      </ul>
    </article>
  );
}
