import type { BlogPost as BlogPostType } from "@/lib/source";
import { getMDXComponents } from "@/mdx-components";
import Link from "next/link";

function formatDateBR(dateStr: string): string {
  const [y, m, d] = dateStr.split("-");
  return `${d}/${m}/${y}`;
}

export function BlogPost({ post }: { post: BlogPostType }) {
  const Content = post.content;

  return (
    <article className="mx-auto max-w-3xl">
      <Link
        href="/blog"
        className="text-fd-muted-foreground text-sm hover:text-fd-foreground mb-8 inline-block"
      >
        &larr; Voltar ao blog
      </Link>

      <header className="mb-8">
        <h1 className="text-3xl font-bold text-fd-foreground mb-3">
          {post.title}
        </h1>
        <div className="flex items-center gap-4 text-sm text-fd-muted-foreground">
          <span>{formatDateBR(post.date)}</span>
          <span>por {post.author}</span>
        </div>
        {post.tags.length > 0 && (
          <div className="flex gap-2 mt-3">
            {post.tags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-fd-secondary px-2.5 py-0.5 text-xs text-fd-muted-foreground"
              >
                {tag}
              </span>
            ))}
          </div>
        )}
      </header>

      <div className="prose prose-neutral dark:prose-invert max-w-none">
        <Content components={getMDXComponents()} />
      </div>
    </article>
  );
}
