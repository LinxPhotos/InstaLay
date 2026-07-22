import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";

const RELEASES = "https://github.com/LinxPhotos/InstaLay/releases/latest";

export default function DownloadPage() {
  return (
    <article class="prose">
      <Title>Download — InstaLay</Title>
      <h1>Download</h1>
      <p>
        Grab the latest desktop packages from GitHub Releases (Windows ZIP/EXE/MSIX,
        macOS DMG/ZIP, Linux tar.gz). InstaLay Free is the same app as InstaLay —
        if you want to support the developer,{" "}
        <A href="/buy">buy a yearly or lifetime license</A>.
      </p>
      <p>
        <a class="btn btn-primary" href={RELEASES} rel="noopener noreferrer">
          Open latest release
        </a>
      </p>
      <ul>
        <li>
          Windows Store package: <code>*-windows-*-store.msix</code>
        </li>
        <li>
          Windows portable / setup: <code>*-windows-*.zip</code> /{" "}
          <code>*-setup.exe</code>
        </li>
        <li>
          macOS: <code>*-macos-*.dmg</code> or <code>.zip</code>
        </li>
        <li>
          Linux: <code>*-linux-*.tar.gz</code>
        </li>
      </ul>
    </article>
  );
}
