# Blog do Pacotinho

Blog sobre gestão de encomendas em condomínios — [blog.pacotinho.com.br](https://blog.pacotinho.com.br)

## Stack

- **Framework**: Next.js 16 + fumadocs-core/mdx/ui
- **Styling**: Tailwind v4
- **Content**: MDX files in `content/blog/`
- **Container**: standalone Next.js, Node.js 24.13.0, usuário não-root
- **Release**: imagem nativa `linux/amd64` imutável em `ghcr.io/c0h1b4/pacotinho-blog`
- **CI**: validação de PR em runner hospedado pelo GitHub
- **Build de release**: runner dedicado `[self-hosted, Linux, X64, pacotinho-blog-builder]`

Este repositório prepara e publica a imagem. Ele não faz deploy, não altera um checkout em servidor de aplicação e não reinicia serviços de produção.

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
tests/
  immutable-release.sh    # Regressões estáticas da cadeia de release
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

### 4. Abra e aprove um PR

Inclua o post em uma branch e abra um pull request para `main`. O workflow **Validate immutable release** executa, em runner hospedado pelo GitHub:

- `actionlint` sobre os workflows;
- regressões estáticas da cadeia imutável;
- instalação pelo lockfile com pnpm 10.11.0;
- build do Next.js;
- build e smoke test de uma imagem nativa `linux/amd64`.

O merge em `main` não faz deploy automático.

### O que o blog gera automaticamente

- OG image com título e excerpt do post
- Post na listagem, no RSS feed e no sitemap
- Filtros clicáveis para as tags
- Posts relacionados por tags em comum
- Botões de compartilhamento (WhatsApp, X, LinkedIn, copiar link)

## Release imutável AMD64

Depois da revisão e do merge:

1. Copie o SHA completo de 40 caracteres do commit em `main` que contém o código e o workflow revisados.
2. Antes do dispatch, um administrador do runner deve revisar esse commit e substituir, como `root`, o conteúdo do allowlist por exatamente `.github/workflows/build-immutable.yml <source_sha>` em `/etc/github-blog-runner/pacotinho-blog-workflows.allow`. Confirme proprietário `root:root`, modo `0644` e o SHA completo; a conta `github-blog-runner` não pode executar essa atualização.
3. Abra **Actions → Build immutable AMD64 image → Run workflow** na branch `main`.
4. Informe o mesmo SHA completo em `source_sha`.
5. Aguarde a verificação da imagem, do SBOM e da proveniência.
6. Baixe o artefato `pacotinho-blog-release-<run>-<attempt>` e use o campo `image.reference` do `release-manifest.json`.

O workflow recusa um `source_sha` que não seja exatamente o `GITHUB_SHA` do `main` revisado e exige que o commit que contém o workflow seja seu ancestral. O contexto entregue ao BuildKit é um `git archive` recriado diretamente do commit validado dentro de um `memfd` anônimo. Antes do build, o workflow confere commit embutido, árvore, Dockerfile, lockfile e SHA-256, aplica no kernel os seals contra escrita, crescimento, redução e novos seals e só então conecta esse descritor imutável ao stdin do Buildx. O manifesto registra o digest e o transporte `sealed-linux-memfd`; não existe arquivo de contexto gravável entre a verificação e o consumo.

A identidade do conteúdo é determinística: `SOURCE_DATE_EPOCH`, a data OCI e o build ID do Next.js vêm do commit revisado, enquanto o label de build deriva somente do repositório, commit, árvore e plataforma. IDs e tentativas do GitHub ficam apenas no manifesto externo. A validação reproduzida compara o fingerprint normalizado de configuração e camadas da imagem; o digest final continua sendo a autoridade de cada execução, enquanto o índice que transporta SBOM e proveniência é registrado separadamente como evidência porque os documentos de atestação podem conter metadados da execução.

A proveniência é SLSA v1 em modo máximo. O gerador do SBOM não usa o alias mutável padrão do BuildKit: o workflow exige `docker/buildkit-syft-scanner@sha256:79e7b013cbec16bbb436f312819a49a4a57752b2270c1a9332ae1a10fcc82a68`, valida o predicado SPDX e registra essa referência imutável no manifesto.

O build publica primeiro por digest e somente depois cria a tag exata de 40 caracteres:

```text
ghcr.io/c0h1b4/pacotinho-blog:<source_sha>
```

A tag serve para localizar a release. A autoridade é sempre a referência por digest registrada no manifesto:

```text
ghcr.io/c0h1b4/pacotinho-blog@sha256:<digest>
```

Antes de promover a tag, o workflow baixa essa referência exata, confirma arquitetura, labels e usuário não-root, inicia um container temporário com filesystem somente-leitura e rede desabilitada, exige que o `HEALTHCHECK` e uma requisição interna a `/blog` passem dentro de 90 segundos e remove o container. Nenhuma imagem reconstruída ou tag intermediária substitui esse teste do digest candidato.

Se a tag do SHA já apontar para o mesmo digest, a nova execução é aceita e apenas confirma a tag existente. Se um digest diferente já estiver visível no preflight, o workflow falha em vez de sobrescrevê-lo. Erros genéricos de autorização, proxy ou `404` não são interpretados como ausência da tag.

GHCR, porém, não documenta criação de tag com compare-and-swap, `create-if-absent` atômico nem política de tag imutável, e o Buildx faz um `PUT` incondicional. Portanto, o intervalo entre inspect/create/inspect não pode impedir uma corrida com outro escritor autorizado nem uma alteração posterior. O manifesto registra `image.tag.authoritative: false` e `image.tag.atomic_create_if_absent: false`; a tag é apenas um localizador observado, nunca a autoridade da release. Enquanto GHCR não oferecer a primitiva necessária, a garantia literal de “jamais sobrescrever sob concorrência” é uma limitação externa não resolvível neste workflow. O acesso de escrita ao pacote deve permanecer exclusivo desta autoridade e qualquer requisito de atomicidade estrita deve bloquear a publicação, não ser declarado como atendido.

Durante o build existe somente um arquivo interno `release-manifest.pending.json`, explicitamente não autoritativo. O `release-manifest.json` autoritativo é finalizado e enviado como artefato somente depois que a tag foi criada ou encontrada e seu digest foi confirmado naquele instante. A autoridade desse manifesto é exclusivamente `image.reference`, qualificada por digest. Uma execução com conflito observado ou falha de promoção não publica um manifesto que alegue uma tag válida.

A implantação é uma etapa separada e deve consumir a referência por digest; este repositório não oferece atalho de deploy para produção.

## Runner protegido do blog

O runner `pacotinho-builder` existente pertence exclusivamente ao repositório `c0h1b4/pacotinho`; seu hook root bloqueia corretamente qualquer job deste blog. Não altere esse hook, não amplie seu allowlist e não adicione a label do blog àquela instalação.

A autoridade de build deste repositório é uma instalação separada e repository-scoped:

| Propriedade | Valor obrigatório |
|-------------|-------------------|
| Repositório de registro | `c0h1b4/pacotinho-blog` |
| Conta de serviço | `github-blog-runner` |
| Root do runner | `/opt/actions-blog-runner` |
| Label customizada | `pacotinho-blog-builder` |
| Workflow aceito | `.github/workflows/build-immutable.yml` |
| Hook root | `/usr/local/sbin/pacotinho-blog-builder-job-started` |
| Allowlist root | `/etc/github-blog-runner/pacotinho-blog-workflows.allow` |
| Workspace esperado | `/opt/actions-blog-runner/_work/pacotinho-blog/pacotinho-blog` |

O provisionamento é uma operação administrativa separada; até ela ser concluída, o workflow fica corretamente sem runner elegível. Registre a instalação somente na URL `https://github.com/c0h1b4/pacotinho-blog`, usando uma registration token efêmera fornecida pelo GitHub, e configure apenas as labels padrão mais `pacotinho-blog-builder`.

Depois de revisar o hook, instale os arquivos como root:

```bash
sudo install -o root -g root -m 0755 \
  ops/runner/pacotinho-blog-runner-job-started \
  /usr/local/sbin/pacotinho-blog-builder-job-started
sudo install -d -o root -g root -m 0755 /etc/github-blog-runner
sudo install -o root -g root -m 0644 \
  ops/runner/pacotinho-blog-workflows.allow.example \
  /etc/github-blog-runner/pacotinho-blog-workflows.allow
```

Substitua o SHA zero do allowlist pelo `GITHUB_WORKFLOW_SHA` exato do commit revisado em `main`. A conta do Actions não pode alterar o hook ou o allowlist. Configure o serviço do runner com o drop-in root-owned:

```ini
[Service]
Environment=ACTIONS_RUNNER_HOOK_JOB_STARTED=/usr/local/sbin/pacotinho-blog-builder-job-started
```

O hook aceita somente repositório, proprietário, evento, branch, workflow e SHA allowlisted do blog. Valide-o offline com:

```bash
ops/runner/test-runner-hook.sh
```

## Desenvolvimento local

Requer Node.js 24.13.0 e pnpm 10.11.0.

```bash
corepack enable
corepack prepare pnpm@10.11.0 --activate
pnpm install --frozen-lockfile
pnpm dev
# Acesse http://localhost:3002/blog
```

Validação local sem publicar imagens:

```bash
pnpm test:release
pnpm build
```
