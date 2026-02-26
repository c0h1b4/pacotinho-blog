import Link from "next/link";

export default function NotFound() {
  return (
    <main className="container mx-auto max-w-3xl px-4 py-24 text-center">
      <h1 className="text-6xl font-bold text-fd-foreground mb-4">404</h1>
      <p className="text-lg text-fd-muted-foreground mb-8">
        Página não encontrada.
      </p>
      <Link
        href="/blog"
        className="inline-block rounded-lg bg-fd-primary text-fd-primary-foreground px-6 py-2.5 text-sm font-medium hover:opacity-90 transition-opacity"
      >
        Voltar ao blog
      </Link>
    </main>
  );
}
