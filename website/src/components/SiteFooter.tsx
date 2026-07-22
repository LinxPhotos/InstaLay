import { LINX } from "../lib/linx";

export function SiteFooter() {
  return (
    <footer class="footer">
      © {new Date().getFullYear()}{" "}
      <a href={LINX.home} rel="noopener noreferrer">
        Linx Photos
      </a>
      {" · "}
      InstaLay
      {" · "}
      <a href="https://github.com/LinxPhotos/InstaLay">GitHub</a>
      {" · "}
      <a href={LINX.docs} rel="noopener noreferrer">
        Linx docs
      </a>
    </footer>
  );
}
