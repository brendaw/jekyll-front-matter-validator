# jekyll-front_matter_validator

Gem que valida o front matter dos seus posts/páginas Jekyll e avisa (ou
quebra o build) quando algo vai dar problema:

- campo obrigatório faltando
- tipo errado (`date` que não é data, `tags` que não é array...)
- valor fora de uma lista permitida (`layout` inválido, por exemplo)
- campo que deveria ser um **slug** (sem acento, sem espaço, sem
  maiúscula) mas não é
- campo cujo valor deveria ter um **asset correspondente** em disco
  (ex.: `cover_image: "gatos-fofos"` deveria existir em
  `assets/images/gatos-fofos.jpg`) e o arquivo não existe

Roda automaticamente em `jekyll build` e `jekyll serve`, e também dá pra
usar como CLI standalone (bom para o hook de `pre-commit` do git).

## Estrutura do gem

```
lib/
  jekyll-front_matter_validator.rb              # ponto de entrada
  jekyll/front_matter_validator/
    version.rb
    core.rb            # toda a lógica de validação (sem depender do Jekyll)
    jekyll_hook.rb      # hook :site, :pre_render (só carrega se Jekyll existir)
exe/
  fmv-validate          # CLI standalone
examples/site-integration/   # arquivos para copiar no repo do SEU SITE
  Gemfile.example
  _config.yml.example
  .githooks/pre-commit
  bin/install-git-hooks.sh
```

## 1. Instalação no seu site Jekyll

Ainda sem publicar no RubyGems, a forma mais simples é vendorizar o gem
dentro do repo do site:

```bash
cp -r jekyll-front_matter_validator vendor/jekyll-front_matter_validator
```

No `Gemfile` do site (veja `examples/site-integration/Gemfile.example`):

```ruby
group :jekyll_plugins do
  gem "jekyll-front_matter_validator", path: "vendor/jekyll-front_matter_validator"
end
```

```bash
bundle install
```

Depois cole o conteúdo de `examples/site-integration/_config.yml.example`
no `_config.yml` do site, ajustando as regras.

> Alternativas: `git:` apontando pra um repositório, ou publicar no
> RubyGems e usar `gem "jekyll-front_matter_validator", "~> 0.2"` normal.
> Veja o `Gemfile.example` pros três formatos.

## 2. Validação em `build` e `serve`

Não precisa fazer mais nada — o Bundler carrega o gem, e o hook
`:site, :pre_render` roda tanto em `jekyll build` quanto em
`jekyll serve` (inclusive a cada regeneração do `--watch`, que é o
padrão do serve).

```bash
bundle exec jekyll build
# ou
bundle exec jekyll serve
```

Se algo estiver inválido e `fail_build_on_error: true` (padrão), o build
para com algo assim:

```
FrontMatterValidator: 3 problema(s) encontrado(s) no front matter
  [ERROR] _posts/2026-01-06-post.md -> slug: esperado tipo 'slug' (esperado algo como 'meu-slug-sem-acento', sem espaço/maiúscula), recebido "Meu Post!"
  [ERROR] _posts/2026-01-06-post.md -> cover_image: nenhum asset encontrado em 'assets/images/gatos-fofos.{jpg,jpeg,png,webp}'
  [ERROR] _posts/2026-01-06-post.md -> layout: valor "artigo" fora da lista permitida ["post", "article"]
```

Para só avisar sem quebrar o build, use `fail_build_on_error: false`.

## 3. Hook de pre-commit do git

Copie a pasta `.githooks/` e o `bin/install-git-hooks.sh` de
`examples/site-integration/` para o repo do site, então:

```bash
./bin/install-git-hooks.sh
```

Isso configura `core.hooksPath` para `.githooks/`. A partir daí, todo
`git commit` roda `bundle exec fmv-validate --staged`, validando só os
arquivos staged, e bloqueia o commit se algo estiver errado.

Para desativar: `git config --unset core.hooksPath`.

## 4. CLI manual

```bash
bundle exec fmv-validate              # valida tudo no projeto
bundle exec fmv-validate --staged      # só os arquivos staged no git
bundle exec fmv-validate caminho.md    # arquivo(s) específico(s)
```

## Referência do schema (`front_matter_schema` no `_config.yml`)

```yaml
front_matter_schema:
  fail_build_on_error: true   # false = só avisa, não quebra o build

  defaults:                   # aplicado a tudo que não bate com collections
    required: [title]
    types: { title: string }

  collections:
    posts:
      path: _posts             # prefixo de caminho que identifica essa collection
      required: [title, date, slug]
      types:
        date: date
        tags: array
        slug: slug
      enum:
        layout: [post, article]
      assets:
        cover_image:
          dir: assets/images
          extensions: [jpg, jpeg, png, webp]
        slug:
          pattern: "assets/posts/{value}/cover.*"
          slugify: true
```

### Tipos suportados em `types:`

`string`, `integer`, `float`, `boolean`, `array`, `hash`, `date`, `slug`.

`slug` valida contra `/\A[a-z0-9]+(-[a-z0-9]+)*\z/` — ou seja, só
minúsculas, números e hífen, sem acento e sem espaço.

### `assets:` — checando se existe um arquivo correspondente

Para cada campo listado em `assets`, o validador monta um caminho
esperado a partir do valor do campo e confere se existe algum arquivo
batendo com ele. Duas formas de configurar:

**`dir` + `extensions`** (mais simples, um arquivo direto numa pasta):

```yaml
assets:
  cover_image:
    dir: assets/images
    extensions: [jpg, jpeg, png, webp]
```
`cover_image: "gatos-fofos"` → procura `assets/images/gatos-fofos.{jpg,jpeg,png,webp}`.

**`pattern`** (mais flexível, com `{value}` como placeholder — útil
para estrutura em subpasta):

```yaml
assets:
  slug:
    pattern: "assets/posts/{value}/cover.*"
```
`slug: "meu-post"` → procura `assets/posts/meu-post/cover.*`.

Em ambos os casos, `slugify: true` normaliza o valor do campo (remove
acento, baixa a caixa, troca espaço por hífen) antes de montar o
caminho — útil quando o campo usado para gerar o nome do arquivo não é
ele mesmo um slug (ex.: usar o `title` para achar a imagem).

### Como as regras são escolhidas por arquivo

Para cada arquivo, o validador procura em `front_matter_schema.collections`
uma entrada cujo `path` seja prefixo do caminho do arquivo (ex.: `_posts`
casa com `_posts/2026-01-05-ola.md`). Se nenhuma bater, usa
`front_matter_schema.defaults`. As regras de `defaults` sempre são
mescladas com as da collection encontrada (campos obrigatórios se somam,
tipos/enums/assets específicos se combinam com os de default).

## Rodando os testes do gem em si

```bash
bundle exec rspec   # se você adicionar specs em spec/
```

(Não veio com specs prontos neste esqueleto — o núcleo em
`lib/jekyll/front_matter_validator/core.rb` é puro Ruby, fácil de
testar isoladamente com `require_relative` + fixtures de front matter.)
