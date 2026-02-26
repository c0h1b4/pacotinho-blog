import Link from "next/link";

export function Header() {
  return (
    <header className="border-b border-fd-border bg-fd-card">
      <nav className="container mx-auto max-w-3xl flex items-center justify-between px-4 h-14">
        <Link href="/blog" className="flex items-center gap-2 font-semibold text-fd-foreground">
          <span className="text-lg">📦</span>
          <span>Pacotinho Blog</span>
        </Link>
        <div className="flex items-center gap-4 sm:gap-6 text-sm">
          <Link href="/blog" className="hidden sm:inline text-fd-muted-foreground hover:text-fd-foreground transition-colors">
            Posts
          </Link>
          <Link href="/feed.xml" className="text-fd-muted-foreground hover:text-fd-foreground transition-colors">
            RSS
          </Link>
          <a
            href="https://pacotinho.com.br"
            className="text-fd-muted-foreground hover:text-fd-foreground transition-colors"
            target="_blank"
            rel="noopener noreferrer"
          >
            <span className="hidden sm:inline">Acessar o App &rarr;</span>
            <span className="sm:hidden">App &rarr;</span>
          </a>
        </div>
      </nav>
    </header>
  );
}
