import type { ReactNode } from "react";
import type { Metadata } from "next";
import { RootProvider } from "fumadocs-ui/provider/next";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { SITE_URL } from "@/lib/source";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Blog — Pacotinho",
    template: "%s — Blog Pacotinho",
  },
  description:
    "Dicas, novidades e conteúdos sobre gestão de encomendas em condomínios.",
  metadataBase: new URL(SITE_URL),
  alternates: {
    canonical: SITE_URL,
    types: { "application/rss+xml": "/feed.xml" },
  },
  openGraph: {
    type: "website",
    locale: "pt_BR",
    siteName: "Pacotinho Blog",
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR" suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider
          search={{ enabled: false }}
          theme={{ defaultTheme: "light", enableSystem: true }}
        >
          <Header />
          <div className="flex-1">{children}</div>
          <Footer />
        </RootProvider>
      </body>
    </html>
  );
}
