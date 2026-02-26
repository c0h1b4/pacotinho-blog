import { getBlogPostSummaries, getAllTags } from "@/lib/source";
import { BlogListClient } from "@/components/BlogListClient";

export default function BlogPage() {
  const posts = getBlogPostSummaries();
  const allTags = getAllTags();

  return (
    <main className="container mx-auto max-w-3xl px-4 py-8 sm:py-12">
      <h1 className="text-2xl sm:text-3xl font-bold text-fd-foreground mb-2">Blog</h1>
      <p className="text-fd-muted-foreground text-sm sm:text-base mb-6 sm:mb-8">
        Dicas, novidades e conteúdos sobre gestão de encomendas em condomínios.
      </p>
      <BlogListClient posts={posts} allTags={allTags} />
    </main>
  );
}
