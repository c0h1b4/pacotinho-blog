"use client";

import { useState, useMemo } from "react";
import Link from "next/link";

interface Post {
  slug: string;
  title: string;
  date: string;
  excerpt: string;
  tags: string[];
  author: string;
  readingTime: number;
}

const POSTS_PER_PAGE = 6;

function formatDateBR(dateStr: string): string {
  const [y, m, d] = dateStr.split("-");
  return `${d}/${m}/${y}`;
}

export function BlogListClient({
  posts,
  allTags,
}: {
  posts: Post[];
  allTags: string[];
}) {
  const [search, setSearch] = useState("");
  const [activeTag, setActiveTag] = useState<string | null>(null);
  const [page, setPage] = useState(1);

  const filtered = useMemo(() => {
    let result = posts;
    if (activeTag) {
      result = result.filter((p) => p.tags.includes(activeTag));
    }
    if (search.trim()) {
      const q = search.toLowerCase();
      result = result.filter(
        (p) =>
          p.title.toLowerCase().includes(q) ||
          p.excerpt.toLowerCase().includes(q) ||
          p.tags.some((t) => t.toLowerCase().includes(q)),
      );
    }
    return result;
  }, [posts, search, activeTag]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / POSTS_PER_PAGE));
  const currentPage = Math.min(page, totalPages);
  const paginated = filtered.slice(
    (currentPage - 1) * POSTS_PER_PAGE,
    currentPage * POSTS_PER_PAGE,
  );

  function handleTagClick(tag: string) {
    setActiveTag(activeTag === tag ? null : tag);
    setPage(1);
  }

  function handleSearch(value: string) {
    setSearch(value);
    setPage(1);
  }

  return (
    <div>
      {/* Search */}
      <div className="mb-6">
        <input
          type="text"
          placeholder="Buscar posts..."
          value={search}
          onChange={(e) => handleSearch(e.target.value)}
          className="w-full rounded-lg border border-fd-border bg-fd-card px-4 py-2.5 text-sm text-fd-foreground placeholder:text-fd-muted-foreground focus:outline-none focus:ring-2 focus:ring-fd-ring"
        />
      </div>

      {/* Tag filters */}
      {allTags.length > 0 && (
        <div className="flex flex-wrap gap-2 mb-6">
          {allTags.map((tag) => (
            <button
              key={tag}
              onClick={() => handleTagClick(tag)}
              className={`rounded-full px-3 py-1 text-xs transition-colors ${
                activeTag === tag
                  ? "bg-fd-primary text-fd-primary-foreground"
                  : "bg-fd-secondary text-fd-muted-foreground hover:bg-fd-accent"
              }`}
            >
              {tag}
            </button>
          ))}
          {activeTag && (
            <button
              onClick={() => { setActiveTag(null); setPage(1); }}
              className="rounded-full px-3 py-1 text-xs text-fd-muted-foreground hover:text-fd-foreground transition-colors"
            >
              Limpar filtro
            </button>
          )}
        </div>
      )}

      {/* Post list */}
      {paginated.length === 0 ? (
        <p className="text-fd-muted-foreground text-center py-12">
          {search || activeTag
            ? "Nenhum post encontrado."
            : "Nenhum post publicado ainda."}
        </p>
      ) : (
        <div className="grid gap-6">
          {paginated.map((post) => (
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
                <span>{post.readingTime} min de leitura</span>
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
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2 mt-8">
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={currentPage <= 1}
            className="rounded-lg border border-fd-border px-3 py-1.5 text-sm text-fd-muted-foreground hover:bg-fd-accent disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            &larr; Anterior
          </button>
          <span className="text-sm text-fd-muted-foreground px-2">
            {currentPage} de {totalPages}
          </span>
          <button
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={currentPage >= totalPages}
            className="rounded-lg border border-fd-border px-3 py-1.5 text-sm text-fd-muted-foreground hover:bg-fd-accent disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            Pr&oacute;ximo &rarr;
          </button>
        </div>
      )}
    </div>
  );
}
