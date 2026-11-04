# Desafio 3.5 — Python para automação: o backup reescrito

Quinto desafio da Fase 3 (Git, Bash e Python) da trilha de estudos: reescrever em Python o backup do [Desafio 3.4](../desafio-04-bash-backup/), com o mesmo comportamento (funções, checagem de root, verificação, rotação e código de saída), e comparar as duas linguagens.

**Script final:** [`scripts/backup.py`](../../../scripts/backup.py) · **Versão em Bash:** [`scripts/backup.sh`](../../../scripts/backup.sh)

**Método:** construir na mesma ordem do Bash (esqueleto → `fazer_backup` → `verificar_backup` → `rotacionar`), comparando cada trecho com o equivalente em Bash, e repetir os mesmos testes.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), Python 3.12 (vem com o sistema: o `dnf` é escrito em Python) |
| **Dados e destino** | `/srv/site`, `/dados/site` → `/backup`, os mesmos do Desafio 3.4 |
| **Repositório** | `~/repos/devops`, branch `script-backup-python` |

---

## Enunciado

O padrão da equipe para automação passa a ser Python, porque os próximos scripts vão lidar com JSON, YAML e APIs. Para aprender comparando, o mesmo backup é reescrito.

### Objetivos

1. `scripts/backup.py` com as mesmas funções: `log`, `fazer_backup`, `verificar_backup`, `rotacionar`.
2. Recusar rodar sem root (`os.geteuid()`).
3. Chamar o `tar` do sistema com `subprocess`, conferindo o resultado.
4. Verificar o backup com o módulo `tarfile`.
5. Rotação com `pathlib`, mantendo os 5 mais recentes.
6. Código de saída certo (`sys.exit`).
7. Provar sucesso e falha; entregar por pull request.

**Bônus:** comparar as duas versões.

> **Por que o `tar` do sistema e não o `tarfile` para criar o backup:** o `tarfile` do Python não guarda as ACLs nem os rótulos do SELinux. O `tar` do sistema cria o arquivo; o Python cuida da lógica, da verificação e da rotação. Chamar programas do sistema a partir do Python é uma das tarefas mais comuns em automação.

---

## O script

```python
#!/usr/bin/env python3
"""Backup do projeto site, com verificação e rotação por quantidade.

Uso: sudo backup.py
"""

import os
import subprocess
import sys
import tarfile
from datetime import datetime
from pathlib import Path

ORIGENS = ["/srv/site", "/dados/site"]
DESTINO = "/backup"
PREFIXO = "site"
MANTER = 5


def log(mensagem):
    agora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{agora} {mensagem}", flush=True)


def fazer_backup():
    data = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    arquivo = f"{DESTINO}/{PREFIXO}-{data}.tar.gz"
    log(f"Criando {arquivo}")
    comando = ["tar", "--acls", "--selinux", "--xattrs", "-czpf", arquivo] + ORIGENS
    resultado = subprocess.run(comando)
    if resultado.returncode != 0:
        log("ERRO: o tar falhou")
        Path(arquivo).unlink(missing_ok=True)
        sys.exit(1)
    return arquivo


def verificar_backup(arquivo):
    try:
        with tarfile.open(arquivo, "r:gz") as tar:
            itens = tar.getnames()
    except (tarfile.TarError, EOFError, OSError) as erro:
        log(f"ERRO: o backup não pôde ser lido ({erro})")
        Path(arquivo).unlink(missing_ok=True)
        sys.exit(1)
    log(f"Backup verificado: {len(itens)} itens")

def rotacionar():
    backups = sorted(
        Path(DESTINO).glob(f"{PREFIXO}-20*.tar.gz"),
        key=lambda caminho: caminho.stat().st_mtime,
        reverse=True,
    )
    for antigo in backups[MANTER:]:
        log(f"Apagando {antigo}")
        antigo.unlink()

def main():
    if os.geteuid() != 0:
        log("ERRO: rode como root (sudo)")
        sys.exit(1)

    log("Início do backup")
    os.umask(0o077)
    os.makedirs(DESTINO, exist_ok=True)
    arquivo = fazer_backup()
    verificar_backup(arquivo)
    rotacionar()
    log("Fim do backup")


if __name__ == "__main__":
    main()
```

---

## Passo a passo

### 1. Esqueleto

| Bash | Python | Diferença |
|---|---|---|
| `#!/bin/bash` | `#!/usr/bin/env python3` | o `env` procura o `python3` no `PATH` |
| `# comentário` | `"""docstring"""` no topo | a descrição oficial do script |
| — | `import os`, `import sys` | as ferramentas vêm em módulos |
| `ORIGENS="/srv/site /dados/site"` | `ORIGENS = ["/srv/site", "/dados/site"]` | uma **lista** de verdade, sem depender de espaços |
| `log() { ... }` com `$1` | `def log(mensagem):` | o argumento tem nome |
| `{ }`, `fi`, `done` | **indentação** de 4 espaços | o recuo define o bloco; não misturar com TAB |
| `echo "$(date ...) $1"` | `print(f"{agora} {mensagem}")` | **f-string**: troca o que está entre `{}` pelo valor |
| `$(id -u)` | `os.geteuid()` | sem chamar outro programa |
| `exit 1` | `sys.exit(1)` | código de saída |

- `flush=True`: a mensagem sai na hora. Sem ele, com a saída capturada (systemd), o Python pode segurar as mensagens e mostrá-las fora de ordem com as do `tar`.
- `def main():` + `if __name__ == "__main__": main()`: a parte principal numa função, chamada só quando o arquivo é **executado** (e não importado por outro script).
- Estilo **PEP 8**: duas linhas em branco entre funções e depois dos imports.

```
$ ./scripts/backup.py
2026-11-04 13:12:32 ERRO: rode como root (sudo)
$ sudo ./scripts/backup.py
2026-11-04 13:12:41 Início do backup
$ echo $?
0
```

### 2. `fazer_backup` com `subprocess`

| Python | Bash | O que faz |
|---|---|---|
| `comando = [..., arquivo] + ORIGENS` | `tar ... "$ARQUIVO" $ORIGENS` | o comando é uma lista: cada item, um argumento. Sem problemas de aspas e espaços |
| `subprocess.run(comando)` | o próprio comando | executa e espera; a saída do `tar` continua na tela |
| `resultado.returncode` | `$?` | código de saída |
| `Path(arquivo).unlink(missing_ok=True)` | `rm -f` | apaga, sem reclamar se não existir |
| `return arquivo` | variável global `ARQUIVO` | a função **devolve** o valor a quem chamou |
| `os.umask(0o077)` | `umask 077` | `0o` = número em octal |
| `os.makedirs(DESTINO, exist_ok=True)` | `mkdir -p` | |

```
$ sudo ./scripts/backup.py
2026-11-04 13:17:21 Início do backup
2026-11-04 13:17:21 Criando /backup/site-2026-11-04_131721.tar.gz
tar: Removendo "/" inicial dos nomes dos membros
tar: Removendo "/" inicial dos alvos de links físicos
2026-11-04 13:17:21 Fim do backup
$ sudo bash -c 'ls -lt /backup | head -3'
-rw-------. 1 root root 1085 nov  4 13:17 site-2026-11-04_131721.tar.gz
```

### 3. `verificar_backup` com `tarfile`

O que o Python faz com o arquivo falso do Desafio 3.4:

```
$ python3 -c 'import tarfile; tarfile.open("/tmp/falso.tar.gz")'
Traceback (most recent call last):
  ...
tarfile.ReadError: file could not be opened successfully:
- method gz: ReadError('not a gzip file')
- method bz2: ReadError('not a bzip2 file')
- method xz: ReadError('not an lzma file')
- method tar: ReadError('truncated header')
```

Sem o formato indicado, o `tarfile.open` tenta todos. A última linha do *traceback* diz o **tipo** do erro, que é o que o `except` captura.

| Trecho | O que faz |
|---|---|
| `try:` / `except (...) as erro:` | tenta; se der um destes erros, trata. No Bash, testava-se o código de saída |
| `with tarfile.open(arquivo, "r:gz") as tar:` | abre para leitura, gzip; o `with` fecha o arquivo no fim, mesmo com erro |
| `tar.getnames()` | lê o backup inteiro e lista os nomes (o `tar -tzf`) |
| `TarError`, `EOFError`, `OSError` | não é tar / arquivo cortado / erro de leitura |
| `len(itens)` | o `wc -l` do Python |

```
2026-11-04 13:19:43 Backup verificado: 5 itens
```

### 4. `rotacionar` com `pathlib`

| Python | Bash | O que faz |
|---|---|---|
| `Path(DESTINO).glob("site-20*.tar.gz")` | `/backup/site-20*.tar.gz` | quem procura é o próprio Python, como root: o problema do `*` com `sudo` do Desafio 3.4 não existe |
| `sorted(..., reverse=True)` | `ls -1t` | do mais novo para o mais antigo |
| `key=lambda caminho: caminho.stat().st_mtime` | o `-t` | ordenar pela data de modificação. `lambda` = função de uma linha, sem nome |
| `backups[MANTER:]` | `tail -n +6` | **fatiamento**: do item 5 em diante (a contagem começa em 0) |
| `antigo.unlink()` | `rm -f` | apaga |

Havia 5 backups da rotação do Bash + 2 do Python + o novo = 8:

```
2026-11-04 13:22:41 Backup verificado: 5 itens
2026-11-04 13:22:41 Apagando /backup/site-2026-11-04_113818.tar.gz
2026-11-04 13:22:41 Apagando /backup/site-2026-11-04_111508.tar.gz
2026-11-04 13:22:41 Apagando /backup/site-2026-11-04_110220.tar.gz
2026-11-04 13:22:41 Fim do backup
```

Ficaram os 5 mais recentes e o `site-teste.tar.gz`.

---

## Testes

**Sem root:** `ERRO: rode como root (sudo)`, código 1.

**Sucesso:** acima, código 0.

**Falha** (com `ORIGENS = ["/srv/site", "/pasta-que-nao-existe"]`):

```
$ grep ORIGENS scripts/backup.py
ORIGENS = ["/srv/site", "/pasta-que-nao-existe"]
$ sudo ./scripts/backup.py
2026-11-04 13:28:56 Início do backup
2026-11-04 13:28:56 Criando /backup/site-2026-11-04_132856.tar.gz
tar: Removendo "/" inicial dos nomes dos membros
tar: Removendo "/" inicial dos alvos de links físicos
tar: /pasta-que-nao-existe: Função stat falhou: Arquivo ou diretório inexistente
tar: Saindo com status de falha em razão de erros anteriores
2026-11-04 13:28:56 ERRO: o tar falhou
$ echo $?
1
$ sudo ls -l /backup
(os mesmos 6 arquivos)
```

A mudança de teste foi desfeita pelo Git:

```
$ git restore scripts/backup.py
$ grep ORIGENS scripts/backup.py
ORIGENS = ["/srv/site", "/dados/site"]
```

**Entrega:** pull request #8.

```
*   b727b17 (HEAD -> main, origin/main, origin/HEAD) Merge pull request #8 from alicevnava/script-backup-python
|\
| * 233cc9d Adiciona o script backup.py, versão em Python do backup
|/
```

O timer continua com a versão em Bash (`/usr/local/bin/backup-site.sh`); as duas fazem o mesmo.

---

## Bônus: Bash x Python

**Conclusão:** "em Python ficou mais simples, mas o Bash é menor" (53 linhas x 73).

| | Bash | Python |
|---|---|---|
| Lista de origens | texto separado por espaços; depende de `$ORIGENS` **sem** aspas | lista de verdade |
| Chamar o `tar` | direto | `subprocess.run([...])` |
| Valores entre funções | variável global que "vaza" da função | `return` e argumentos |
| Erros | código de saída de cada comando | código de saída **e** exceções por tipo (`try`/`except`) |
| `*` com `sudo` | expandido pelo shell de quem chama | o `glob` roda dentro do script |
| Tamanho | menor | maior |

**Regra prática:** Bash para colar comandos do sistema em poucas linhas; Python quando aparecem lógica, listas, tratamento de erro ou dados estruturados (JSON, YAML, APIs).

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `-bash: import: comando não encontrado` | Código Python digitado no terminal | Escrever dentro do `scripts/backup.py`, pelo `vi` |
| O primeiro teste de falha terminou com sucesso | A linha `ORIGENS` não tinha sido alterada | Conferir com `grep ORIGENS scripts/backup.py` antes de rodar |
| Funções separadas por uma linha em branco (ainda antes de `rotacionar` e de `main`) | Estilo (o Python roda igual) | PEP 8 pede duas linhas em branco entre funções: um ajuste pequeno para um próximo pull request |

---

## Resumo

- Python para automação: `import`, `def`, indentação de 4 espaços, f-strings, `if __name__ == "__main__":`.
- `subprocess.run([...])` chama programas do sistema; `.returncode` é o `$?`.
- `tarfile` lê arquivos `.tar.gz`; `try`/`except` captura erros por tipo; `with` garante o fechamento.
- `pathlib.Path`: `glob`, `stat().st_mtime`, `unlink`. `sorted(key=..., reverse=True)` e fatiamento `[N:]` fazem a rotação.
- `os.geteuid()`, `os.umask(0o077)`, `os.makedirs(exist_ok=True)`, `sys.exit(1)`.
- `print(..., flush=True)` mantém a ordem das mensagens quando a saída é capturada.
- `git restore` desfaz uma mudança de teste.
