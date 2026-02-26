import { getBlogPostSummaries } from "@/lib/source";
import { BlogList } from "@/components/BlogList";

export default function BlogPage() {
  const posts = getBlogPostSummaries();

  return (
    <main className="container mx-auto max-w-3xl px-4 py-12">
      <h1 className="text-3xl font-bold text-fd-foreground mb-2">Blog</h1>
      <p className="text-fd-muted-foreground mb-8">
        Dicas, novidades e conteúdos sobre gestão de encomendas em condomínios.
      </p>
      <BlogList posts={posts} />
    </main>
  );
}
