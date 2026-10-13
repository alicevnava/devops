# Guia: publicar uma documentação do Notion no GitHub

Passo a passo para levar uma documentação escrita no **Notion** para este repositório, como um `README.md` com imagens, usando o **Git pelo terminal** (Git Bash ou MSYS2 no Windows).

> Objetivo: repetir o processo para qualquer documentação, sempre do mesmo jeito.

## Sumário

- [Conceitos](#conceitos)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Parte 1 - Configuração inicial (uma vez por computador)](#parte-1---configuração-inicial-uma-vez-por-computador)
- [Parte 2 - Antes de começar a trabalhar](#parte-2---antes-de-começar-a-trabalhar)
- [Parte 3 - Do Notion para o Git](#parte-3---do-notion-para-o-git)
- [Parte 4 - Link no README principal](#parte-4---link-no-readme-principal)
- [Comandos de consulta e correção](#comandos-de-consulta-e-correção)
- [Boas práticas de documentação](#boas-práticas-de-documentação)
- [Erros comuns](#erros-comuns)

---

## Conceitos

| Termo | Significado |
| --- | --- |
| Repositório | Pasta acompanhada pelo Git, com todo o histórico de alterações |
| `origin` | Apelido do repositório no GitHub (de onde ele foi clonado) |
| `main` | Ramo (branch) principal do repositório |
| Commit | Uma "fotografia" das alterações, gravada no histórico com uma mensagem |
| `.git/` | Pasta oculta onde o Git guarda o histórico. Nunca apagar |

O fluxo básico tem três passos:

| Comando | O que faz | Comparação |
| --- | --- | --- |
| `git add` | Escolhe quais alterações vão no próximo commit | Colocar as coisas na caixa |
| `git commit` | Grava as alterações no histórico **do computador** | Fechar e etiquetar a caixa |
| `git push` | Envia os commits para o **GitHub** | Mandar a caixa pelo correio |

---

## Estrutura do repositório

Cada documentação fica numa pasta própria, com o texto no `README.md` e os prints em `imagens/`. O GitHub mostra o `README.md` automaticamente ao abrir a pasta.

```
devops/
├── README.md              ← índice: um link para cada documentação
├── NOME-DA-PASTA/
│   ├── README.md
│   └── imagens/
└── NOME-DA-PASTA/
    ├── README.md
    └── imagens/
```

Nos comandos abaixo, troque **`NOME-DA-PASTA`** pelo nome da documentação (minúsculas, sem espaço, sem acento, com hífen: `lab-moodle`, `guia-git`...).

---

## Parte 1 - Configuração inicial (uma vez por computador)

Conferir a instalação do Git:

```bash
git --version
```

Esperado: `git version 2.x.x`.

Identificar a autora dos commits (o e-mail deve ser o mesmo da conta do GitHub, é ele que liga os commits ao perfil):

```bash
git config --global user.name "SEU NOME"
git config --global user.email "SEU_EMAIL_DO_GITHUB"
git config --global --list
```

Esperado: as linhas `user.name=...` e `user.email=...`.

Baixar (clonar) o repositório:

```bash
cd ~/Documents
git clone https://github.com/alicevnava/devops.git
cd devops
ls -la
git status
```

Esperado: a pasta `.git/`, os arquivos do repositório e `nothing to commit, working tree clean`.

> No primeiro `git push`, o Git Credential Manager abre o navegador para o login no GitHub. O GitHub não aceita a senha da conta no terminal.

---

## Parte 2 - Antes de começar a trabalhar

Sempre que voltar ao repositório:

```bash
cd ~/Documents/devops
git pull
git status
```

| Comando | Para quê | Esperado |
| --- | --- | --- |
| `cd ~/Documents/devops` | Entrar no repositório | O prompt mostra `(main)` |
| `git pull` | Trazer do GitHub o que mudou (por exemplo, edições feitas pelo site) | `Already up to date.` |
| `git status` | Conferir que não há nada pendente | `working tree clean` |

> O prompt mostra onde você está: `~/Documents/devops (main)` é dentro do repositório; sem o `(main)`, está fora de qualquer repositório.

---

## Parte 3 - Do Notion para o Git

### 3.1 Exportar do Notion

Na página do Notion: **⋯** (canto superior direito) → **Exportar** → **Markdown & CSV** → **Exportar**.

O `.zip` vai para a pasta **Downloads**, com o `.md` da página e as imagens.

### 3.2 Criar a pasta da documentação

```bash
mkdir -p NOME-DA-PASTA/imagens
ls -R NOME-DA-PASTA
```

> O Git não guarda pastas vazias: a pasta só aparece no GitHub quando tiver arquivos.

### 3.3 Colocar o texto

Descompactar o export numa pasta separada:

```bash
mkdir -p ~/Downloads/export-notion
unzip ~/Downloads/NOME_DO_ZIP.zip -d ~/Downloads/export-notion
ls ~/Downloads/export-notion
```

Copiar o `.md` como `README.md`. Nomes com espaço vão entre aspas, mas o `~` fica **fora** delas (entre aspas ele não é trocado pela pasta pessoal):

```bash
cp ~/Downloads/export-notion/"NOME DO ARQUIVO.md" NOME-DA-PASTA/README.md
head -20 NOME-DA-PASTA/README.md
```

Esperado: o título e o começo do texto.

### 3.4 Revisar o texto

Esta é a etapa mais importante.

Procurar senhas, chaves e tokens:

```bash
grep -n -i -E "senha|password|identified by|token|\.pem" NOME-DA-PASTA/README.md
```

Esperado: só linhas com `********` ou marcadores (`SENHA_...`). Qualquer senha real deve ser removida.

Procurar aspas curvas (o Notion troca as aspas retas e os comandos param de funcionar):

```bash
grep -n -E "’|”|‘|“" NOME-DA-PASTA/README.md
```

Esperado: nenhuma linha. Se aparecer, trocar por `'` e `"`.

Editar:

```bash
vim NOME-DA-PASTA/README.md
```

Checklist de revisão:

- [ ] Nenhuma senha, chave, token, IP público ou ID de instância
- [ ] Pré-requisitos e variáveis no início
- [ ] Comandos em blocos de código, um por linha
- [ ] Marcadores no lugar dos valores do meu ambiente (`SEU_ENDERECO`...)
- [ ] Ordem real de execução, só com os comandos que funcionaram
- [ ] Resultado esperado em cada passo
- [ ] Imagens só de resultados (telas), não de comandos

### 3.5 Colocar as imagens

Salvar os prints com nomes **em minúsculas, sem espaço e sem acento**, com um **prefixo** em comum (`sei-`, `moodle-`...). No Windows, a pasta "Capturas de Tela" fica em `~/Pictures/Screenshots`.

Conferir e copiar:

```bash
ls ~/Pictures/Screenshots | grep PREFIXO-
cp ~/Pictures/Screenshots/PREFIXO-*.png NOME-DA-PASTA/imagens/
ls -l NOME-DA-PASTA/imagens
```

> O `*` significa "qualquer coisa": `PREFIXO-*.png` pega todos os arquivos que começam com o prefixo. Conferir os tamanhos: prints de até cerca de 1 MB.

No README, cada imagem fica numa linha própria, com uma linha em branco antes e depois:

```markdown
![Descrição da imagem](imagens/nome-do-arquivo.png)
```

| Parte | Significado |
| --- | --- |
| `!` | Indica imagem (sem ele, vira link) |
| `[ ]` | Texto alternativo: aparece se a imagem não carregar e é lido por leitores de tela |
| `( )` | Caminho do arquivo, relativo ao README |

Conferir as imagens citadas:

```bash
grep -n "imagens/" NOME-DA-PASTA/README.md
```

Esperado: todas as linhas começando com `![`, nenhuma dentro de `<!-- -->`.

### 3.6 Enviar para o GitHub

```bash
git status
git add NOME-DA-PASTA
git status
git commit -m "Adiciona documentacao de NOME DO ASSUNTO"
git push
git log --oneline -3
```

| Comando | Esperado |
| --- | --- |
| `git status` | `Untracked files: NOME-DA-PASTA/` |
| `git add NOME-DA-PASTA` | Nenhuma saída (o aviso `LF will be replaced by CRLF` é normal no Windows) |
| `git status` | Arquivos em verde: `new file: ...` |
| `git commit -m "..."` | `[main xxxxxxx] ...` e a quantidade de arquivos e linhas |
| `git push` | `xxxxxxx..yyyyyyy  main -> main` |
| `git log --oneline -3` | O commit novo no topo, com `origin/main` |

Mensagem de commit: frase curta, no presente, dizendo o que o commit faz (`Adiciona...`, `Corrige...`, `Atualiza...`).

---

## Parte 4 - Link no README principal

```bash
vim README.md
```

Na seção `## Laboratórios` (ou `## Guias`), acrescentar uma linha na tabela:

```markdown
| [Nome da documentação](NOME-DA-PASTA/) | Descrição curta |
```

Conferir e enviar:

```bash
git diff
git add README.md
git commit -m "Adiciona link de NOME DO ASSUNTO no README principal"
git push
```

O `git diff` mostra as linhas alteradas: `+` adicionadas, `-` removidas. Para sair, `q`.

Por fim, abrir o repositório no navegador e conferir o texto, as tabelas e as imagens.

---

## Comandos de consulta e correção

| Comando | Para quê |
| --- | --- |
| `git status` | Estado atual |
| `git diff` | O que mudou e ainda não foi para o `add` |
| `git log --oneline -5` | Últimos 5 commits |
| `git restore ARQUIVO` | Desfazer as alterações de um arquivo ainda não adicionado (o que foi alterado se perde) |
| `git restore --staged ARQUIVO` | Tirar um arquivo do `add`, sem perder a alteração |

| Estado no `git status` | Significado |
| --- | --- |
| `Untracked files` | Arquivo novo que o Git ainda não acompanha |
| `Changes not staged for commit` | Arquivo acompanhado e alterado, ainda sem `add` |
| `Changes to be committed` | Preparado para o commit |
| `ahead of 'origin/main' by N commits` | Commits que ainda não foram para o GitHub |
| `up to date with 'origin/main'` | Igual ao GitHub |

### Copiei o arquivo errado: como trocar

Funciona em qualquer momento (antes ou depois do `add`, do `commit` ou do `push`): basta **copiar o arquivo certo por cima** e fazer um novo ciclo de add → commit → push. O Git guarda a versão errada no histórico, mas o que aparece no GitHub é sempre a versão mais recente.

Descobrir o nome do arquivo certo (navegadores salvam repetidos como `README (1).md`, `README (2).md`):

```bash
ls -lt ~/Downloads | grep -i readme
```

O `-t` ordena pelos mais recentes: o primeiro da lista costuma ser o último baixado.

Conferir o conteúdo antes de copiar:

```bash
head -5 ~/Downloads/"README (1).md"
```

Copiar por cima do errado e conferir:

```bash
cp ~/Downloads/"README (1).md" NOME-DA-PASTA/README.md
head -5 NOME-DA-PASTA/README.md
git status
```

| O que o `git status` mostra | Situação | O que fazer |
| --- | --- | --- |
| `Untracked files` | Ainda não tinha feito `add` | Seguir normalmente: add → commit → push |
| `Changes to be committed` + `Changes not staged` no mesmo arquivo | Tinha feito `add`, mas não `commit` | Fazer o `add` de novo (pega a versão nova) → commit → push |
| `Changes not staged for commit` | Já tinha feito `commit` (e talvez `push`) | add → commit (mensagem: `Corrige ...`) → push |
| `nothing to commit` | O arquivo copiado é igual ao anterior | O arquivo errado foi copiado de novo: conferir o nome |

```bash
git add NOME-DA-PASTA/README.md
git commit -m "Corrige README de NOME DO ASSUNTO"
git push
```

> Não apagar commits que já foram para o GitHub. Corrigir sempre com um commit novo: o histórico fica honesto e não gera conflito.

---

## Boas práticas de documentação

Critério principal: **alguém que nunca viu o assunto, numa máquina nova, consegue refazer tudo só lendo o documento.**

Uma boa documentação tem:

1. **Contexto**: objetivo, arquitetura e resultado esperado
2. **Pré-requisitos**: sistema, recursos, acessos, portas, internet, arquivos e downloads externos
3. **Variáveis**: tabela de marcadores (`SEU_ENDERECO`, `SUA_SIGLA`...) para os valores que mudam
4. **Passo a passo**: o que e por quê, o comando, o resultado esperado e como conferir
5. **Arquivos de configuração completos**
6. **Decisões e adaptações**: onde fugiu do manual e por quê
7. **Validação final**: checklist de testes
8. **Problemas conhecidos e soluções**
9. **Referências**

Não pode ter:

| Erro | Por que atrapalha |
| --- | --- |
| Senhas, chaves e dados de acesso | Risco de segurança |
| Comandos com erro ou aspas curvas | Quem copia recebe erro |
| "Configurar o arquivo X" sem o conteúdo | Impossível replicar |
| Prints de comandos | Não dá para copiar um comando de uma imagem |
| Tentativas que deram errado no meio do passo a passo | A pessoa repete o erro |

Teste final: seguir a documentação numa máquina nova, copiando e colando, sem usar a memória.

---

## Erros comuns

| Erro | Causa | Solução |
| --- | --- | --- |
| `ls: cannot access '-'` | Espaço dentro da opção (`ls - la`) | Opção junta: `ls -la` |
| `bash: ![Menu: event not found` | Texto do arquivo digitado no terminal | Abrir o arquivo no vim e escrever lá |
| Imagem não aparece no GitHub | Linha dentro de `<!-- -->` ou nome diferente do arquivo | Conferir com `grep -n "imagens/"` |
| Imagens espremidas lado a lado | Imagens em linhas seguidas | Linha em branco entre elas |
| Pede `Username` e `Password` no push | Login pelo navegador não configurado | Usar o Git Credential Manager (não aceita senha da conta) |
| Pasta não aparece no GitHub | Pasta vazia | Colocar arquivos antes do commit |
| Conteúdo de outro documento no README | Copiado o arquivo errado de Downloads (nomes repetidos viram `README (1).md`) | Ver [Copiei o arquivo errado](#copiei-o-arquivo-errado-como-trocar) |
| `warning: LF will be replaced by CRLF` | Aviso do Git no Windows sobre quebras de linha | Normal, não é erro |

---

Autora: Alice Vivas Nava — [@alicevnava](https://github.com/alicevnava)
