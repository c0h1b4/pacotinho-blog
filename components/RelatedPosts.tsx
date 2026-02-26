import Link from "next/link";
import type { BlogPostSummary } from "@/lib/source";

function formatDateBR(dateStr: string): string {
  const [y, m, d] = dateStr.split("-");
  return `${d}/${m}/${y}`;
}

export function RelatedPosts({ posts }: { posts: BlogPostSummary[] }) {
  if (posts.length === 0) return null;

  return (
    <section className="mt-12 pt-8 border-t border-fd-border">
      <h2 className="text-lg font-semibold text-fd-foreground mb-4">
        Posts relacionados
      </h2>
      <div className="grid gap-4">
        {posts.map((post) => (
          <Link
            key={post.slug}
            href={`/blog/${post.slug}`}
            className="block rounded-lg border border-fd-border bg-fd-card p-4 transition-colors hover:bg-fd-accent"
          >
            <h3 className="font-medium text-fd-foreground mb-1">
              {post.title}
            </h3>
            <p className="text-fd-muted-foreground text-sm line-clamp-2">
              {post.excerpt}
            </p>
            <span className="text-xs text-fd-muted-foreground mt-2 inline-block">
              {formatDateBR(post.date)} &middot; {post.readingTime} min de leitura
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}
