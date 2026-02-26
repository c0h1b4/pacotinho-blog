import Link from "next/link";
import type { BlogPostSummary } from "@/lib/source";

function formatDateBR(dateStr: string): string {
  const [y, m, d] = dateStr.split("-");
  return `${d}/${m}/${y}`;
}

export function BlogList({ posts }: { posts: BlogPostSummary[] }) {
  if (posts.length === 0) {
    return (
      <p className="text-fd-muted-foreground text-center py-12">
        Nenhum post publicado ainda.
      </p>
    );
  }

  return (
    <div className="grid gap-6">
      {posts.map((post) => (
        <Link
          key={post.slug}
          href={`/blog/${post.slug}`}
          className="block rounded-lg border border-fd-border bg-fd-card p-6 transition-colors hover:bg-fd-accent"
        >
          <h2 className="text-xl font-semibold text-fd-foreground mb-2">
            {post.title}
          </h2>
          <p className="text-fd-muted-foreground text-sm mb-3">
            {post.excerpt}
          </p>
          <div className="flex items-center gap-4 text-xs text-fd-muted-foreground">
            <span>{formatDateBR(post.date)}</span>
            <span>por {post.author}</span>
            {post.tags.length > 0 && (
              <div className="flex gap-1.5">
                {post.tags.map((tag) => (
                  <span
                    key={tag}
                    className="rounded-full bg-fd-secondary px-2 py-0.5"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            )}
          </div>
        </Link>
      ))}
    </div>
  );
}
