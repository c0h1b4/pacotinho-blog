import type { ReactNode } from "react";
import { blog } from "fumadocs-mdx:collections/server";
import type { MDXProps } from "mdx/types";

export interface BlogPost {
  slug: string;
  title: string;
  date: string;
  excerpt: string;
  tags: string[];
  author: string;
  content: React.ComponentType<MDXProps>;
  toc: { id: string; text: ReactNode; depth: number }[];
}

export interface BlogPostSummary {
  slug: string;
  title: string;
  date: string;
  excerpt: string;
  tags: string[];
  author: string;
}

function formatDate(date: unknown): string {
  if (!date) return "";
  if (typeof date === "string") {
    if (/^\d{4}-\d{2}-\d{2}$/.test(date)) return date;
    const parsed = new Date(date);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString().split("T")[0];
    return date;
  }
  if (date instanceof Date) return date.toISOString().split("T")[0];
  return String(date);
}

export function getBlogPosts(): BlogPost[] {
  return blog.map((entry) => {
    const slug = entry.info.path.replace(/\.mdx?$/, "");
    return {
      slug,
      title: entry.title,
      date: formatDate(entry.date),
      excerpt: entry.excerpt,
      tags: entry.tags,
      author: entry.author,
      content: entry.body,
      toc: entry.toc.map((item) => ({
        id: item.url.slice(1),
        text: item.title,
        depth: item.depth,
      })),
    };
  });
}

export function getBlogPostSummaries(): BlogPostSummary[] {
  return getBlogPosts()
    .map(({ content, toc, ...rest }) => rest)
    .sort((a, b) => b.date.localeCompare(a.date));
}

export function getBlogPost(slug: string): BlogPost | undefined {
  return getBlogPosts().find((p) => p.slug === slug);
}

export function getAllBlogSlugs(): string[] {
  return getBlogPosts().map((p) => p.slug);
}
