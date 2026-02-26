import type { MetadataRoute } from "next";
import { getBlogPostSummaries, SITE_URL } from "@/lib/source";

export default function sitemap(): MetadataRoute.Sitemap {
  const posts = getBlogPostSummaries();

  const blogEntries: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `${SITE_URL}/blog/${post.slug}`,
    lastModified: new Date(post.date),
    changeFrequency: "monthly",
    priority: 0.8,
  }));

  return [
    {
      url: `${SITE_URL}/blog`,
      lastModified: new Date(),
      changeFrequency: "daily",
      priority: 1.0,
    },
    ...blogEntries,
  ];
}
