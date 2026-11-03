# Desafio 3.1 — Git na prática

Primeiro desafio da Fase 3 (Git, Bash e Python) da trilha de estudos: configurar o Git num servidor Linux, autenticar no GitHub por SSH e passar pelo fluxo completo de trabalho em equipe: branch, commit, push, pull request, merge, conflito e desfazer um commit publicado.

**Método:** `git status` antes e depois de cada passo; testes de conflito e de revert em branches descartáveis, sem mexer na `main`.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), usuário `alice_estudo` |
| **Repositório** | [`alicevnava/devops`](https://github.com/alicevnava/devops) no GitHub |
| **Pasta local** | `~/repos/devops` |

> Nome, e-mail e repositório são os meus. Troque pelos seus ao refazer.

---

## Conceitos

| Termo | Significa |
|---|---|
| **Repositório** | a pasta do projeto mais todo o histórico de mudanças (a pasta oculta `.git`) |
| **Commit** | uma "foto" dos arquivos, com autor, data, mensagem e um identificador (hash) |
| **Área de preparação** (*staging*) | o que vai entrar no próximo commit (`git add`) |
| **Branch** | uma linha de trabalho separada; a `main` é a principal |
| **`origin`** | o nome do repositório remoto (o GitHub) |
| **Pull request (PR)** | o pedido para juntar uma branch na `main`, com revisão no GitHub |
| **Merge** | juntar o trabalho de duas branches |
| **Fast-forward** | merge em que só se "avança o ponteiro", porque um lado não tem commits novos |
| **Conflito** | duas branches mudaram a mesma linha de jeitos diferentes; o Git pede para a pessoa decidir |

**Regra da equipe:** ninguém mexe direto na `main`. Toda mudança vai numa branch, vira pull request e entra depois de revisada.

---

## Enunciado

A equipe vai guardar os scripts de automação num repositório Git. Os scripts da Fase 3 vão morar no repositório `devops`, numa pasta `scripts/`, e entram na `main` pelo fluxo de pull request.

### Objetivos

1. **Instalar e configurar** o Git: nome, e-mail, branch padrão `main` e editor.
2. **Autenticar no GitHub por SSH** a partir do servidor, com uma chave só para isso.
3. **Clonar** o repositório.
4. Criar uma **branch**, adicionar `scripts/README.md`, fazer **commit** e **push**, abrir o **pull request** e fazer o **merge**.
5. **Provocar e resolver um conflito.**
6. **Ler o histórico:** `log --graph`, `show`, `diff`.

**Bônus:** desfazer um commit já enviado com `git revert` e explicar por que não usar `git reset`.

---

## Passo a passo

### 1. Instalar e configurar

```bash
sudo dnf install -y git
git --version
git config --global user.name "Alice Vivas"
git config --global user.email "<seu e-mail do GitHub>"
git config --global init.defaultBranch main
git config --global core.editor vi
git config --global --list
cat ~/.gitconfig
```

| Configuração | Para quê |
|---|---|
| `user.name` / `user.email` | aparecem em **todo** commit. O e-mail igual ao da conta liga os commits ao perfil do GitHub (para não expor o e-mail, o GitHub oferece um `...@users.noreply.github.com` em Settings → Emails) |
| `init.defaultBranch main` | repositórios novos começam na `main`, não na `master` |
| `core.editor` | editor que o Git abre para mensagens de commit e de merge |
| `--global` | vale para todos os repositórios do usuário; fica em `~/.gitconfig` |

```
git version 2.52.0
user.name=Alice Vivas
user.email=...
init.defaultbranch=main
core.editor=vim
```

As chaves do Git não diferenciam maiúsculas de minúsculas: o `--list` mostra `init.defaultbranch`, o arquivo guarda `defaultBranch`.

> ⚠️ Na instalação mínima do Rocky só existe o comando **`vi`** (pacote `vim-minimal`); o `vim` vem no `vim-enhanced`. Com `core.editor vim`, o `git commit` falhou com `cannot run vim`. Corrigido com `git config --global core.editor vi` (ou `sudo dnf install -y vim-enhanced`).

### 2. Chave SSH para o GitHub

É o inverso do [Desafio 1.9](../../fase-1-linux/desafio-09-ssh-chave/): agora é o **servidor** que se autentica no **GitHub**.

```bash
ls -la ~/.ssh
ssh-keygen -t ed25519 -C "servidor1-github"
cat ~/.ssh/id_ed25519.pub
```

| Parte | O que faz |
|---|---|
| `-t ed25519` | tipo de chave moderno e curto |
| `-C "servidor1-github"` | comentário no fim da chave pública, para identificar a origem na lista do GitHub |
| passphrase | protege a chave privada; é pedida a cada `push`/`pull` |

No GitHub: **Settings → SSH and GPG keys → New SSH key**, Title `servidor1`, Key type `Authentication Key`, colando a **linha inteira** do `.pub` (tipo, chave e comentário; sem o prompt).

```
$ ssh -T git@github.com
The authenticity of host 'github.com (4.228.31.150)' can't be established.
ED25519 key fingerprint is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Enter passphrase for key '/home/alice_estudo/.ssh/id_ed25519':
Hi alicevnava! You've successfully authenticated, but GitHub does not provide shell access.
```

- **Antes do `yes`**, conferir a impressão digital com a publicada pelo GitHub ("GitHub's SSH key fingerprints"). Se não bater, alguém pode estar no meio.
- `-T`: sem terminal; o GitHub só confirma se a chave foi aceita.
- Todo mundo usa o usuário `git`; é a chave que identifica a pessoa.

### 3. Clonar

```bash
mkdir ~/repos
cd ~/repos
git clone git@github.com:alicevnava/devops.git
cd devops
git status
git remote -v
git log --oneline -5
```

```
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean

origin  git@github.com:alicevnava/devops.git (fetch)
origin  git@github.com:alicevnava/devops.git (push)

5bff410 (HEAD -> main, origin/main, origin/HEAD) Desafio 2.5: bastion SSH (fecha a Fase 2)
```

| Marcador | Significa |
|---|---|
| `HEAD -> main` | onde eu estou |
| `origin/main` | onde está a `main` do GitHub, na última conversa com ele |
| `origin/HEAD` | a branch padrão do GitHub |

O endereço SSH (`git@github.com:...`) serve para baixar **e** enviar. Pelo `https://`, o GitHub não aceita mais senha no `push`: exige um token.

### 4. Branch, commit, push e pull request

```bash
git switch -c fase-3-scripts
mkdir scripts
vi scripts/README.md
git status
```

```
On branch fase-3-scripts
Untracked files:
        scripts/
```

`Untracked`: o Git vê, mas não acompanha.

```bash
git add scripts/README.md
git status
git commit -m "Cria a pasta scripts da Fase 3"
git push -u origin fase-3-scripts
```

```
Changes to be committed:
        new file:   scripts/README.md

[fase-3-scripts 0049d39] Cria a pasta scripts da Fase 3
 1 file changed, 6 insertions(+)
 create mode 100644 scripts/README.md

remote: Create a pull request for 'fase-3-scripts' on GitHub by visiting:
remote:      https://github.com/alicevnava/devops/pull/new/fase-3-scripts
 * [new branch]      fase-3-scripts -> fase-3-scripts
branch 'fase-3-scripts' set up to track 'origin/fase-3-scripts'.
```

| Comando | O que faz |
|---|---|
| `git switch -c <branch>` | cria a branch a partir de onde estou e muda para ela |
| `git add` | coloca na área de preparação |
| `git commit -m` | grava o commit |
| `git push -u origin <branch>` | envia a branch; o `-u` liga a branch local à remota (depois basta `git push`) |

No GitHub: **Compare & pull request** → base `main` ← compare `fase-3-scripts` → **Create pull request** → revisão na aba **Files changed** → **Merge pull request** → **Delete branch**.

Trazendo o merge para o servidor:

```bash
git switch main
git pull
git log --oneline --graph -5
```

```
From github.com:alicevnava/devops
   5bff410..16ac04d  main       -> origin/main
Updating 5bff410..16ac04d
Fast-forward
 scripts/README.md | 6 ++++++

*   16ac04d (HEAD -> main, origin/main, origin/HEAD) Merge pull request #1 from alicevnava/fase-3-scripts
|\
| * 0049d39 (origin/fase-3-scripts, fase-3-scripts) Cria a pasta scripts da Fase 3
|/
* 5bff410 Desafio 2.5: bastion SSH (fecha a Fase 2)
```

- **`Fast-forward`:** a `main` local não tinha commits novos; o Git só avançou o ponteiro.
- **`Merge pull request #1`:** o commit de merge criado pelo GitHub, juntando o galho da branch.

Arrumação da branch usada:

```bash
git fetch --prune
git branch -d fase-3-scripts
git branch -a
```

| Comando | O que faz |
|---|---|
| `git fetch --prune` | atualiza as informações do GitHub e remove referências de branches que não existem mais lá |
| `git branch -d` | apaga a branch local, **só se** ela já entrou na `main` |
| `git branch -a` | lista branches locais e remotas |

### 5. Conflito

Duas branches de teste, saindo da `main`, mudando a **mesma linha** (linha 3 do `scripts/README.md`):

```bash
git switch -c teste-a
vi scripts/README.md          # linha 3: "Scripts de automação em Bash da Fase 3."
git commit -am "Descrição da pasta: versão A"

git switch main
git switch -c teste-b
vi scripts/README.md          # linha 3: "Scripts de automação em Python da Fase 3."
git commit -am "Descrição da pasta: versão B"

git switch teste-a
git merge teste-b
```

`commit -a` inclui automaticamente os arquivos **já acompanhados** que foram modificados (arquivos novos ainda precisam de `git add`).

```
Auto-merging scripts/README.md
CONFLICT (content): Merge conflict in scripts/README.md
Automatic merge failed; fix conflicts and then commit the result.

$ git status
On branch teste-a
You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)
Unmerged paths:
        both modified:   scripts/README.md

$ cat scripts/README.md
# Scripts

<<<<<<< HEAD
Scripts de automação em Bash da Fase 3.
=======
Scripts de automação em Python da Fase 3.
>>>>>>> teste-b
```

| Marcador | Significa |
|---|---|
| `<<<<<<< HEAD` | começa a versão da branch atual (`teste-a`) |
| `=======` | separa as versões |
| `>>>>>>> teste-b` | termina a versão que está chegando |

O resto do arquivo não tem marcador: ali as branches concordavam. `git merge --abort` desistiria do merge.

**Resolução:** apagar as 5 linhas do conflito e deixar uma versão que junta as duas (no `vi`: `3G`, `5dd`, `O`, digitar, `Esc`, `:wq`):

```
Scripts de automação em Bash e Python da Fase 3.
```

```bash
cat scripts/README.md        # conferir que não sobrou marcador
git add scripts/README.md    # "este arquivo está resolvido"
git commit                   # abre o editor com "Merge branch 'teste-b' into teste-a"
git log --oneline --graph -5
```

```
*   b1207d4 (HEAD -> teste-a) Merge branch 'teste-b' into teste-a
|\
| * 571caf0 (teste-b) Descrição da pasta: versão B
* | 89e1534 Descrição da pasta: versão A
|/
*   16ac04d (origin/main, origin/HEAD, main) Merge pull request #1 from alicevnava/fase-3-scripts
```

O commit de merge `b1207d4` tem **dois pais** (`89e1534` e `571caf0`). Um marcador esquecido no arquivo seria gravado como texto comum: o Git não confere isso.

Arrumação:

```
$ git switch main
$ git branch -d teste-a
error: the branch 'teste-a' is not fully merged
$ git branch -D teste-a
Deleted branch teste-a (was b1207d4).
$ git branch -D teste-b
Deleted branch teste-b (was 571caf0).
```

O `-d` recusa apagar uma branch cujos commits não estão na `main`; o `-D` força.

### 6. Ler o histórico

```
$ git show 0049d39
commit 0049d39f16fb385f6776ec5a53b1d8692977e137
Author: Alice Vivas <...>
Date:   Tue Nov 3 14:08:25 2026 -0300

    Cria a pasta scripts da Fase 3

diff --git a/scripts/README.md b/scripts/README.md
new file mode 100644
index 0000000..0bac8b9
--- /dev/null
+++ b/scripts/README.md
@@ -0,0 +1,6 @@
+# Scripts
+
+Scripts de automação da Fase 3 (Git, Bash e Python) da trilha de estudos.
+
+| Script | O que faz |
+| --- | --- |
```

Uma linha de teste acrescentada no fim do README, sem commit:

```
$ git diff
diff --git a/scripts/README.md b/scripts/README.md
index 0bac8b9..39acc76 100644
--- a/scripts/README.md
+++ b/scripts/README.md
@@ -4,3 +4,4 @@ Scripts de automação da Fase 3 (Git, Bash e Python) da trilha de estudos.

 | Script | O que faz |
 | --- | --- |
+| (em breve) | primeiro script |

$ git restore scripts/README.md
$ git status
nothing to commit, working tree clean
```

| Parte do diff | Significa |
|---|---|
| `--- a/...` / `+++ b/...` | versão antes / depois (`/dev/null` = o arquivo não existia) |
| `@@ -4,3 +4,4 @@` | o trecho tinha 3 linhas a partir da linha 4; agora tem 4 |
| `+` | linha adicionada (`-` seria removida) |
| espaço na frente | contexto: não mudou |

| Comando | Mostra |
|---|---|
| `git show <hash>` | um commit: autor, data, mensagem e o diff |
| `git diff` | mudanças ainda **não** preparadas com `git add` |
| `git restore <arquivo>` | descarta as mudanças não gravadas (perde de vez) |

### Bônus: `revert` x `reset`

Numa branch de teste, um commit "errado" enviado ao GitHub e desfeito com `revert`:

```bash
git switch -c teste-revert
vi scripts/README.md                 # acrescenta "LINHA ERRADA"
git commit -am "Commit com erro"
git push -u origin teste-revert
git revert HEAD                      # abre o editor com 'Revert "Commit com erro"'
git log --oneline -3
git push
```

```
0011bdf (HEAD -> teste-revert) Revert "Commit com erro"
4f5884a (origin/teste-revert) Commit com erro
16ac04d (origin/main, origin/HEAD, main) Merge pull request #1 from alicevnava/fase-3-scripts

To github.com:alicevnava/devops.git
   4f5884a..0011bdf  teste-revert -> teste-revert
```

O erro e a correção ficam no histórico, e o push é normal, porque a branch só avançou.

| | `git revert` | `git reset --hard` |
|---|---|---|
| O que faz | cria um commit que faz o contrário | apaga commits, voltando o ponteiro |
| Histórico | preservado | reescrito |
| Depois de publicado | `git push` normal | push **recusado** (`non-fast-forward`); só passa com `--force`, e quem já tinha baixado fica com um histórico que não existe mais |

**Regra:** commit publicado se desfaz com `revert`; `reset` só para commits que ainda não saíram da máquina.

Arrumação:

```bash
git switch main
git push origin --delete teste-revert
git branch -D teste-revert
```

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `Received disconnect from ... port 22:11: Bye Bye` no primeiro `clone` | A passphrase demorou; o GitHub encerra a conexão se a autenticação não chega a tempo | Rodar de novo e digitar sem pausa |
| Arquivo salvo como `README.ms` | Erro de digitação | `mv scripts/README.ms scripts/README.md` (como o arquivo ainda não estava no Git, um `mv` comum resolve; depois do commit, seria `git mv`) |
| `Permission denied (publickey)` no `git pull`, depois de três pedidos de passphrase | Passphrase digitada errado. `ssh-keygen -y -f ~/.ssh/id_ed25519` confirmou localmente: `incorrect passphrase` | Não há recuperação de passphrase: chave nova com `ssh-keygen`, a antiga apagada do GitHub e a nova cadastrada |
| `ssh -T` com `Permission denied` sem pedir passphrase, logo após criar a chave nova | O GitHub ainda só conhecia a chave antiga; o SSH só destrava a chave privada depois que o servidor aceita a pública | Cadastrar a nova `.pub` no GitHub |
| `error: cannot run vim: Arquivo ou diretório inexistente` no `git commit` | `core.editor vim`, mas a instalação mínima só tem o `vi` | `git config --global core.editor vi` |
| `error: the branch 'teste-a' is not fully merged` | O `-d` protege commits que não estão na `main` | `git branch -D` (era uma branch de teste) |

---

## Resumo

- Identidade (`user.name`, `user.email`) antes do primeiro commit: ela vai em todo commit.
- Servidor no GitHub = chave SSH própria do servidor, conferindo a impressão digital do GitHub na primeira conexão. `ssh-keygen -y -f` testa a passphrase localmente.
- Fluxo: `switch -c` → editar → `status` → `add` → `commit` → `push -u` → PR → merge → `switch main` → `pull` → `fetch --prune` + `branch -d`.
- Conflito: ler os marcadores, decidir, apagar os marcadores, `add`, `commit`. `merge --abort` desiste.
- `log --oneline --graph`, `show`, `diff` e `restore` para ler e controlar o que mudou.
- Publicado → `revert`. `reset` só no que é local.
