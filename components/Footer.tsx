import Link from "next/link";

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-fd-border mt-auto">
      <div className="container mx-auto max-w-3xl px-4 py-8">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 text-sm text-fd-muted-foreground">
          <p>&copy; {year} Pacotinho. Todos os direitos reservados.</p>
          <div className="flex items-center gap-4">
            <Link href="/blog" className="hover:text-fd-foreground transition-colors">
              Blog
            </Link>
            <Link href="/feed.xml" className="hover:text-fd-foreground transition-colors">
              RSS
            </Link>
            <a
              href="https://pacotinho.com.br"
              className="hover:text-fd-foreground transition-colors"
              target="_blank"
              rel="noopener noreferrer"
            >
              pacotinho.com.br
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
