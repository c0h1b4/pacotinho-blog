import { ImageResponse } from "next/og";
import { getBlogPost, getAllBlogSlugs } from "@/lib/source";

export const alt = "Pacotinho Blog";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export function generateStaticParams() {
  return getAllBlogSlugs().map((slug) => ({ slug }));
}

export default async function OGImage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const post = getBlogPost(slug);
  const title = post?.title ?? "Pacotinho Blog";
  const excerpt = post?.excerpt ?? "";

  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          width: "100%",
          height: "100%",
          padding: "60px",
          background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
          color: "white",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
          <span style={{ fontSize: "36px" }}>📦</span>
          <span style={{ fontSize: "24px", opacity: 0.8 }}>Pacotinho Blog</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <div
            style={{
              fontSize: "48px",
              fontWeight: "bold",
              lineHeight: 1.2,
              maxWidth: "900px",
            }}
          >
            {title}
          </div>
          {excerpt && (
            <div
              style={{
                fontSize: "22px",
                opacity: 0.7,
                lineHeight: 1.4,
                maxWidth: "800px",
              }}
            >
              {excerpt.length > 120 ? excerpt.slice(0, 120) + "..." : excerpt}
            </div>
          )}
        </div>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            opacity: 0.6,
            fontSize: "18px",
          }}
        >
          <span>blog.pacotinho.com.br</span>
          {post && <span>{post.date}</span>}
        </div>
      </div>
    ),
    { ...size },
  );
}
