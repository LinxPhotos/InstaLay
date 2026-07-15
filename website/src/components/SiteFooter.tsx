export function SiteFooter() {
  return (
    <footer class="footer">
      © {new Date().getFullYear()}{" "}
      <a href="https://linx.photos/">Linx</a>
      {" · "}
      InstaLay
      {" · "}
      <a href="https://github.com/LinxPhotos/insta-lay">GitHub</a>
      {" · "}
      <a href="https://github.com/LinxPhotos/docs.linx.photos">Docs</a>
    </footer>
  );
}
