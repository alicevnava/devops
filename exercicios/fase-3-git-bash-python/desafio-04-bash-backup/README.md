# Desafio 3.4 — Bash II: o backup completo

Quarto desafio da Fase 3 (Git, Bash e Python) da trilha de estudos: reescrever o script de backup do [Desafio 1.10](../../fase-1-linux/desafio-10-backup-cron-timer/) como um script organizado em **funções**, que **confere** cada etapa, **registra** o que faz e só apaga os backups antigos **depois** de garantir que o novo está bom. O script mora no repositório e é instalado no servidor a partir dele.

**Script final:** [`scripts/backup.sh`](../../../scripts/backup.sh), instalado como `/usr/local/bin/backup-site.sh`

**Método:** uma função por vez, testando a cada passo; ensaio do que seria apagado **antes** de colocar o `rm` no script; prova de que uma falha não apaga nada.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2) |
| **Dados** | `/srv/site` e `/dados/site` ([Desafio 1.10](../../fase-1-linux/desafio-10-backup-cron-timer/)) |
| **Destino** | `/backup` (`drwx------`, só do root) |
| **Agendamento** | `backup-site.timer` + `backup-site.service` do Desafio 1.10, todo dia às 02:30, com `Persistent=true` |
| **Repositório** | `~/repos/devops`, configurado no [Desafio 3.1](../desafio-01-git/) |

---

## O ponto de partida

```
$ sudo cat /usr/local/bin/backup-site.sh
#!/bin/bash
umask 077
DESTINO=/backup
ARQUIVO=$DESTINO/site-$(date +%F_%H%M).tar.gz

tar --acls --selinux --xattrs -czpf "$ARQUIVO" /srv/site /dados/site

find "$DESTINO" -name 'site-*.tar.gz' -mtime +7 -delete
```

| Problema | Consequência |
|---|---|
| O resultado do `tar` não é conferido | Um backup incompleto passa como bom, e a rotação roda mesmo assim |
| Rotação por **idade** (`-mtime +7`) | Se o backup parar por uma semana, a rotação apaga **todos** |
| Nada é registrado | No journal, só os avisos do `tar`: não dá para saber o que foi criado nem apagado |
| Só existe na VM | Sem versão nem histórico |

```
$ systemctl list-timers backup-site.timer
NEXT                        LEFT LAST                              PASSED       UNIT
Thu 2026-11-05 02:30:00 -03  16h Wed 2026-11-04 07:53:02 -03 2h 27min ago   backup-site.timer
```

Com a VM desligada às 02:30, o `Persistent=true` rodou o backup logo depois de ligar (07:53). Em `/backup` havia 15 arquivos: os 9 do teste do cron "a cada minuto" de 27/10, um por dia vindo do timer, e o `site-teste.tar.gz` manual.

---

## Enunciado

### Objetivos

1. Organizar o script em **funções**: `log`, `fazer_backup`, `verificar_backup`, `rotacionar`.
2. Recusar rodar **sem root**.
3. Gerar o backup com **data e hora no nome**, conferindo o código de saída do `tar`.
4. **Verificar** o arquivo gerado (`tar -tzf`); se não abrir, apagar e sair com erro, **sem** rotação.
5. Rotação por **quantidade**: manter os **5 mais recentes**.
6. **Instalar** a partir do repositório e fazer o timer usar a versão nova; provar pelo `journalctl`.
7. Entregar por **pull request**.

**Bônus:** provar que um backup com erro não apaga os antigos.

---

## O script

```bash
#!/bin/bash
# Backup do projeto site, com verificação e rotação por quantidade.
# Uso: sudo backup.sh

ORIGENS="/srv/site /dados/site"
DESTINO="/backup"
PREFIXO="site"
MANTER=5
umask 077

log() {
    echo "$(date '+%F %T') $1"
}

fazer_backup() {
    ARQUIVO="$DESTINO/$PREFIXO-$(date +%F_%H%M%S).tar.gz"
    log "Criando $ARQUIVO"
    if ! tar --acls --selinux --xattrs -czpf "$ARQUIVO" $ORIGENS; then
        log "ERRO: o tar falhou"
        rm -f "$ARQUIVO"
        exit 1
    fi
}

verificar_backup() {
    if ! tar -tzf "$ARQUIVO" > /dev/null; then
        log "ERRO: o backup não pôde ser lido"
        rm -f "$ARQUIVO"
        exit 1
    fi
    log "Backup verificado: $(tar -tzf "$ARQUIVO" | wc -l) itens"
}

rotacionar() {
    ANTIGOS=$(ls -1t "$DESTINO/$PREFIXO"-20*.tar.gz | tail -n +$((MANTER + 1)))
    for antigo in $ANTIGOS; do
        log "Apagando $antigo"
        rm -f "$antigo"
    done
}

if [ "$(id -u)" -ne 0 ]; then
    log "ERRO: rode como root (sudo)"
    exit 1
fi

log "Início do backup"

mkdir -p "$DESTINO"
fazer_backup
verificar_backup
rotacionar
log "Fim do backup"
```

**Estrutura:** configurações no topo → definição das funções → checagens → chamadas, na ordem. As funções precisam ser **definidas antes** de serem chamadas, e definir não executa: só a chamada (o nome sozinho numa linha) roda a função.

**A ordem das chamadas é a garantia do script:** `fazer_backup` e `verificar_backup` dão `exit 1` ao falhar, então `rotacionar` **só roda** se existir um backup novo que abre.

---

## Passo a passo

### 1. Esqueleto: `log` e checagem de root

| Trecho | O que faz |
|---|---|
| `ORIGENS`, `DESTINO`, `PREFIXO`, `MANTER` | configurações juntas no topo |
| `log() { ... }` | define a função; `$1` **dentro da função** é o primeiro argumento passado **a ela** |
| `date '+%F %T'` | `2026-11-04 10:24:43` (`%F` = data, `%T` = hora) |
| `id -u` | número do usuário; o root é **0** |

```
$ ./scripts/backup.sh
2026-11-04 10:24:43 ERRO: rode como root (sudo)
$ sudo ./scripts/backup.sh
2026-11-04 10:24:56 Início do backup
$ echo $?
0
```

### 2. `fazer_backup`

| Trecho | O que faz |
|---|---|
| `umask 077` | backups nascem `600` |
| `%H%M%S` | segundos no nome: dois testes no mesmo minuto não se sobrescrevem |
| `if ! tar ...; then` | "se o `tar` **falhou**" (`!` inverte o código de saída) |
| `$ORIGENS` sem aspas | para o Bash separar as duas pastas em dois argumentos |
| `rm -f "$ARQUIVO"` | não deixa um backup pela metade parecendo bom |
| `mkdir -p "$DESTINO"` | cria a pasta se não existir |

```
$ sudo ./scripts/backup.sh
2026-11-04 10:29:06 Início do backup
2026-11-04 10:29:06 Criando /backup/site-2026-11-04_102906.tar.gz
tar: Removendo "/" inicial dos nomes dos membros
tar: Removendo "/" inicial dos alvos de links físicos
2026-11-04 10:29:06 Fim do backup
```

O aviso `Removendo "/"` é o mesmo do Desafio 1.10: o `tar` grava caminhos relativos para a restauração não sobrescrever o sistema.

### 3. `verificar_backup`

O `tar` terminar com 0 não garante que o arquivo **abre** (disco cheio no meio, por exemplo). A verificação lê o backup de volta.

```
$ echo "isso não é um backup" > /tmp/falso.tar.gz
$ tar -tzf /tmp/falso.tar.gz

gzip: stdin: not in gzip format
tar: Child returned status 1
tar: Error is not recoverable: exiting now
$ echo $?
2

$ sudo tar -tzf /backup/site-2026-11-04_102906.tar.gz
srv/site/
srv/site/teste-bruno
srv/site/teste2.txt
dados/site/
dados/site/teste-backup.txt
$ echo $?
0
```

A extensão `.tar.gz` é só parte do nome; quem diz se é um backup é o conteúdo.

| Trecho | O que faz |
|---|---|
| `tar -tzf` | lista (`-t`) um `.tar.gz` (`-z`) sem extrair |
| `> /dev/null` | só interessa o código de saída |
| `"$ARQUIVO"` | a variável criada **dentro** de `fazer_backup`: no Bash, variáveis criadas numa função valem no script todo |

```
2026-11-04 11:15:08 Backup verificado: 5 itens
```

### 4. `rotacionar`

**Ensaio, sem apagar nada:**

```
$ sudo ls -1t /backup/site-20*.tar.gz
ls: não foi possível acessar '/backup/site-20*.tar.gz': Arquivo ou diretório inexistente
```

Quem expande o `*` é o **shell do usuário**, antes do `sudo`. Como `/backup` é `drwx------` (só o root vê o conteúdo), a expansão não acha nada e o `ls` recebe o texto literal com `*`. Solução: o shell do root expande.

```
$ sudo bash -c 'ls -1t /backup/site-20*.tar.gz | tail -n +6'
/backup/site-2026-10-30_0314.tar.gz
/backup/site-2026-10-29_0830.tar.gz
...
/backup/site-2026-10-27_1422.tar.gz
```

| Parte | O que faz |
|---|---|
| `sudo bash -c '...'` | um Bash como root executa o texto; as aspas simples impedem o shell do usuário de mexer no `*` |
| `ls -1t` | um por linha, do mais novo para o mais antigo |
| `site-20*.tar.gz` | só backups com data no nome. Com `site-*`, o `site-teste.tar.gz` seria apagado um dia |
| `tail -n +6` | da sexta linha em diante: pula os 5 mais novos |

No script, `tail -n +$((MANTER + 1))` se ajusta sozinho se `MANTER` mudar. Ele roda inteiro como root, então o `*` funciona.

```
$ sudo ./scripts/backup.sh
2026-11-04 11:38:18 Início do backup
2026-11-04 11:38:18 Criando /backup/site-2026-11-04_113818.tar.gz
...
2026-11-04 11:38:18 Backup verificado: 5 itens
2026-11-04 11:38:18 Apagando /backup/site-2026-11-03_0859.tar.gz
2026-11-04 11:38:18 Apagando /backup/site-2026-10-30_0314.tar.gz
...
2026-11-04 11:38:18 Apagando /backup/site-2026-10-27_1422.tar.gz
2026-11-04 11:38:18 Fim do backup

$ sudo ls -l /backup
-rw-------. 1 root root 1086 nov  4 07:53 site-2026-11-04_0753.tar.gz
-rw-------. 1 root root 1086 nov  4 10:29 site-2026-11-04_102906.tar.gz
-rw-------. 1 root root 1085 nov  4 11:02 site-2026-11-04_110220.tar.gz
-rw-------. 1 root root 1085 nov  4 11:15 site-2026-11-04_111508.tar.gz
-rw-------. 1 root root 1085 nov  4 11:38 site-2026-11-04_113818.tar.gz
-rw-------. 1 root root 1100 out 27 14:10 site-teste.tar.gz
```

13 apagados, 5 mantidos, e o `site-teste.tar.gz` intacto.

### 5. Bônus: um backup com erro não apaga nada

Com `ORIGENS="/srv/site /pasta-que-nao-existe"`, temporariamente:

```
$ sudo ./scripts/backup.sh
2026-11-04 11:39:56 Início do backup
2026-11-04 11:39:56 Criando /backup/site-2026-11-04_113956.tar.gz
tar: Removendo "/" inicial dos nomes dos membros
tar: Removendo "/" inicial dos alvos de links físicos
tar: /pasta-que-nao-existe: Função stat falhou: Arquivo ou diretório inexistente
tar: Saindo com status de falha em razão de erros anteriores
2026-11-04 11:39:56 ERRO: o tar falhou
$ echo $?
1
$ sudo ls -l /backup
(os mesmos 6 arquivos)
```

O `tar` chegou a gravar o `/srv/site` antes de falhar: existiu um backup **incompleto**. O `rm -f` o apagou, e a rotação nem rodou. O script antigo teria guardado o incompleto e rodado o `find -delete` do mesmo jeito.

Com a linha de volta ao normal, tudo voltou a funcionar (e a rotação apagou 1 para manter os 5).

### 6. Instalar e usar no timer

```bash
sudo install -m 700 -o root -g root scripts/backup.sh /usr/local/bin/backup-site.sh
sudo diff scripts/backup.sh /usr/local/bin/backup-site.sh
ls -lZ /usr/local/bin/backup-site.sh
```

```
-rwx------. 1 root root system_u:object_r:bin_t:s0 1105 nov  4 11:41 /usr/local/bin/backup-site.sh
```

| Parte | O que faz |
|---|---|
| `install -m 700 -o root -g root` | copia e já define permissão, dono e grupo (em vez de `cp` + `chmod` + `chown`) |
| mesmo nome do script antigo | a unidade `backup-site.service` continua igual |
| `diff` sem saída | o instalado é idêntico ao do repositório |
| `bin_t` | o rótulo SELinux da pasta, que permite ao systemd executar |

```
$ sudo systemctl start backup-site.service
$ sudo systemctl status backup-site.service
○ backup-site.service - Backup do projeto site
     Active: inactive (dead) since Wed 2026-11-04 11:42:07 -03; 6s ago
TriggeredBy: ● backup-site.timer
    Process: 197611 ExecStart=/usr/local/bin/backup-site.sh (code=exited, status=0/SUCCESS)

$ sudo journalctl -u backup-site.service -n 15 --no-pager
nov 04 07:53:02 ... backup-site.sh[111482]: tar: Removendo "/" inicial dos nomes dos membros
nov 04 07:53:02 ... backup-site.sh[111482]: tar: Removendo "/" inicial dos alvos de links físicos
nov 04 07:53:02 ... systemd[1]: Finished backup-site.service - Backup do projeto site.
nov 04 11:42:07 ... backup-site.sh[197611]: 2026-11-04 11:42:07 Início do backup
nov 04 11:42:07 ... backup-site.sh[197611]: 2026-11-04 11:42:07 Criando /backup/site-2026-11-04_114207.tar.gz
nov 04 11:42:07 ... backup-site.sh[197617]: tar: Removendo "/" inicial dos nomes dos membros
nov 04 11:42:07 ... backup-site.sh[197617]: tar: Removendo "/" inicial dos alvos de links físicos
nov 04 11:42:07 ... backup-site.sh[197611]: 2026-11-04 11:42:07 Backup verificado: 5 itens
nov 04 11:42:07 ... backup-site.sh[197611]: 2026-11-04 11:42:07 Apagando /backup/site-2026-11-04_102906.tar.gz
nov 04 11:42:07 ... backup-site.sh[197611]: 2026-11-04 11:42:07 Fim do backup
nov 04 11:42:07 ... systemd[1]: Finished backup-site.service - Backup do projeto site.
```

- **07:53 (script antigo):** só os avisos do `tar`.
- **11:42 (script novo):** cada etapa, com hora. Todo `echo` do script vai para o journal.
- `[197611]` é o script; `[197617]` é o `tar`, processo filho.
- `status=0/SUCCESS`: com uma falha, seria `1/FAILURE`, e a unidade apareceria em `systemctl --failed`.

### 7. Entrega

Linha nova no [`scripts/README.md`](../../../scripts/README.md), commit, `git push -u origin script-backup`, pull request #7, merge, delete branch.

```
*   3662c8a (HEAD -> main, origin/main, origin/HEAD) Merge pull request #7 from alicevnava/script-backup
|\
| * bf4e630 Adiciona o script backup.sh com verificação e rotação
|/
```

> Para atualizar o servidor depois de uma mudança no script: `git pull` no repositório e o mesmo `sudo install ...`.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `Received disconnect ... Bye Bye` no `git fetch` | Passphrase demorou | Rodar de novo; para não digitar a cada comando, `eval "$(ssh-agent)"` + `ssh-add` (vale até sair da sessão) |
| A linha `Backup verificado` não apareceu | Chamada escrita `verificar backup` (com espaço): o Bash procura um comando `verificar` com o argumento `backup`, dá `comando não encontrado` e **continua**, terminando com 0 | `verificar_backup`, igual à definição. Lição: conferir o conteúdo da saída, não só o `$?` |
| `ls: não foi possível acessar '/backup/site-20*.tar.gz'` com `sudo` | O `*` é expandido pelo shell do usuário, que não enxerga dentro de `/backup` (`drwx------`) | `sudo bash -c '...'` |

---

## Resumo

- Funções: `nome() { ... }`, definidas antes de chamadas; `$1` dentro dela é o argumento da função. Variáveis criadas numa função valem no script todo.
- Cada etapa confere o código de saída e, se falhar, limpa (`rm -f`) e sai (`exit 1`).
- Verificar um backup = lê-lo de volta (`tar -tzf`).
- Rotação por quantidade (`ls -1t | tail -n +N`) é mais segura que por idade. Ensaiar o que seria apagado antes de pôr `rm` num script.
- A **ordem** das chamadas garante que nada é apagado sem um backup novo e bom.
- `install -m 700 -o root -g root` para colocar no servidor o script do repositório; mesmo nome = a unidade do systemd não muda.
- `echo` + systemd = registro no journal; `exit` correto = `SUCCESS`/`FAILURE` no `systemctl status`.
- O `*` é do shell, não do comando: com `sudo`, quem expande é quem chama.
