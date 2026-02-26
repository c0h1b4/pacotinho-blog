# Blog do Pacotinho

Blog sobre gestão de encomendas em condomínios — [blog.pacotinho.com.br](https://blog.pacotinho.com.br)

## Stack

- **Framework**: Next.js 16 + fumadocs-core/mdx/ui
- **Styling**: Tailwind v4
- **Content**: MDX files in `content/blog/`
- **Deploy**: Docker (standalone) on arm01, port 3002
- **CI/CD**: GitHub Actions → self-hosted runner `arm01-blog`

## Features

- Search (client-side, filters by title/excerpt/tags)
- Tag filtering (clickable tag pills)
- Pagination (6 posts per page)
- RSS feed (`/feed.xml`)
- Sitemap (`/sitemap.xml`) + robots.txt
- Dynamic OG images (1200x630, per post)
- Social sharing (WhatsApp, X, LinkedIn, copy link)
- Reading time estimate (computed from word count)
- Related posts (matched by shared tags)
- Dark/light theme (system preference)
- SEO: canonical URLs, Open Graph, Twitter cards

## Project Structure

```
app/
  layout.tsx              # RootProvider, Header, Footer, metadata
  page.tsx                # Redirects to /blog
  not-found.tsx           # Custom 404 (PT-BR)
  globals.css             # Tailwind v4 + fumadocs CSS
  icon.svg                # Favicon
  sitemap.ts              # Dynamic sitemap
  robots.ts               # robots.txt
  blog/
    page.tsx              # Blog listing (search, tags, pagination)
    [slug]/
      page.tsx            # Individual post
      opengraph-image.tsx # Dynamic OG image
  feed.xml/
    route.ts              # RSS feed
components/
  Header.tsx              # Navbar (logo, nav links)
  Footer.tsx              # Copyright, links
  BlogListClient.tsx      # Client component: search, tag filter, pagination
  BlogPost.tsx            # Post renderer (reading time, tags)
  ShareButtons.tsx        # WhatsApp, X, LinkedIn, copy link
  RelatedPosts.tsx        # Related posts section
content/blog/
  bem-vindo.mdx           # Example post
lib/source.ts             # Blog post loader, reading time, related posts
source.config.ts          # fumadocs collection + Zod schema
mdx-components.tsx        # MDX overrides
```

## Como publicar um post

### 1. Crie o arquivo MDX

Crie um arquivo em `content/blog/<slug>.mdx`. O slug (nome do arquivo) será a URL do post.

**Convenções para o slug:**
- Letras minúsculas, sem acentos
- Palavras separadas por hífen
- Exemplos: `como-rastrear-encomendas.mdx`, `dicas-para-porteiros.mdx`

### 2. Adicione o frontmatter

Todo post precisa começar com o bloco de metadados:

```yaml
---
title: Título do Post
date: 2026-02-26
excerpt: Resumo curto que aparece na listagem do blog.
tags: [pacotinho, dicas]
author: Mark
---
```

| Campo | Obrigatório | Descrição |
|-------|-------------|-----------|
| `title` | Sim | Título exibido no post e na listagem |
| `date` | Sim | Data no formato `YYYY-MM-DD` |
| `excerpt` | Sim | Resumo curto (1-2 frases) para a listagem e SEO |
| `tags` | Sim | Lista de tags (array YAML) — usadas para filtro e posts relacionados |
| `author` | Não | Nome do autor (padrão: "Pacotinho") |

### 3. Escreva o conteúdo

Use Markdown padrão abaixo do frontmatter:

```markdown
## Subtítulo

Parágrafo com **negrito** e *itálico*.

- Item de lista
- Outro item

### Sub-subtítulo

> Citação em bloco

![Descrição da imagem](/imagem.png)
```

O tempo de leitura é calculado automaticamente a partir do conteúdo.

### 4. Publique

```bash
git add content/blog/meu-novo-post.mdx
git commit -m "post: título do post"
git push origin main
```

O deploy automático via GitHub Actions leva ~1 minuto. O post estará disponível em `https://blog.pacotinho.com.br/blog/<slug>`.

### O que acontece automaticamente

- OG image gerada com título e excerpt do post
- Post aparece na listagem, no RSS feed e no sitemap
- Tags viram filtros clicáveis na listagem
- Posts com tags em comum aparecem como "Posts relacionados"
- Botões de compartilhamento (WhatsApp, X, LinkedIn, copiar link)

## Desenvolvimento local

```bash
pnpm install
pnpm dev
# Acesse http://localhost:3002/blog
```

## Deploy manual

```bash
ssh ubuntu@arm01 "cd /home/ubuntu/pacotinho-blog && git pull && docker compose up -d --build"
```
