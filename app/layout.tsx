import type { ReactNode } from "react";
import type { Metadata } from "next";
import { RootProvider } from "fumadocs-ui/provider/next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Blog — Pacotinho",
    template: "%s — Blog Pacotinho",
  },
  description:
    "Dicas, novidades e conteúdos sobre gestão de encomendas em condomínios.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR" suppressHydrationWarning>
      <body>
        <RootProvider
          search={{ enabled: false }}
          theme={{ defaultTheme: "light", enableSystem: true }}
        >
          {children}
        </RootProvider>
      </body>
    </html>
  );
}
