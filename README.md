# Blog do Pacotinho

Blog sobre gestão de encomendas em condomínios — [blog.pacotinho.com.br](https://blog.pacotinho.com.br)

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
| `excerpt` | Sim | Resumo curto (1-2 frases) para a listagem |
| `tags` | Sim | Lista de tags (array YAML) |
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

### 4. Publique

```bash
git add content/blog/meu-novo-post.mdx
git commit -m "post: título do post"
git push origin main
```

O deploy automático via GitHub Actions leva ~2 minutos. O post estará disponível em `https://blog.pacotinho.com.br/blog/<slug>`.

## Desenvolvimento local

```bash
pnpm install
pnpm dev
# Acesse http://localhost:3002/blog
```
