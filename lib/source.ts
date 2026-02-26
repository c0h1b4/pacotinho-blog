import type { ReactNode } from "react";
import { blog } from "fumadocs-mdx:collections/server";
import type { MDXProps } from "mdx/types";
import fs from "fs";
import path from "path";

export const SITE_URL = "https://blog.pacotinho.com.br";

export interface BlogPost {
  slug: string;
  title: string;
  date: string;
  excerpt: string;
  tags: string[];
  author: string;
  readingTime: number;
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
  readingTime: number;
}

function formatDate(date: unknown): string {
  if (!date) return "";
  if (typeof date === "string") {
    if (/^\d{4}-\d{2}-\d{2}$/.test(date)) return date;
    const parsed = new Date(date);
    if (!Number.isNaN(parsed.getTime()))
      return parsed.toISOString().split("T")[0];
    return date;
  }
  if (date instanceof Date) return date.toISOString().split("T")[0];
  return String(date);
}

function computeReadingTime(slug: string): number {
  try {
    const filePath = path.join(process.cwd(), "content/blog", `${slug}.mdx`);
    const raw = fs.readFileSync(filePath, "utf-8");
    const body = raw.replace(/^---[\s\S]*?---/, "");
    const words = body.trim().split(/\s+/).length;
    return Math.max(1, Math.ceil(words / 200));
  } catch {
    return 1;
  }
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
      readingTime: computeReadingTime(slug),
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

export function getAllTags(): string[] {
  const tags = new Set<string>();
  for (const post of getBlogPosts()) {
    for (const tag of post.tags) tags.add(tag);
  }
  return Array.from(tags).sort();
}

export function getRelatedPosts(
  currentSlug: string,
  limit = 3,
): BlogPostSummary[] {
  const current = getBlogPost(currentSlug);
  if (!current) return [];

  const others = getBlogPostSummaries().filter((p) => p.slug !== currentSlug);

  return others
    .map((post) => {
      const shared = post.tags.filter((t) => current.tags.includes(t)).length;
      return { post, score: shared };
    })
    .sort((a, b) => b.score - a.score || b.post.date.localeCompare(a.post.date))
    .slice(0, limit)
    .filter((r) => r.score > 0)
    .map((r) => r.post);
}
