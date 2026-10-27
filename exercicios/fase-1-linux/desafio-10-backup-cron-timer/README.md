# Desafio 10 — cron, Timers e tar: o Backup que Ninguém Fazia

Décimo desafio da Fase 1 (Linux sólido) da trilha de estudos: criar um backup com `tar` preservando permissões especiais, provar que ele restaura, automatizar com um script, agendar com cron e migrar o agendamento para um timer do systemd.

**Método:** um backup só vale se restaura. Testar a restauração antes de automatizar.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), `servidor1.estudos.local` |
| **Dados do backup** | `/srv/site` ([Desafio 2](../desafio-02-pasta-compartilhada/), com setgid e ACL da Carla) e `/dados/site` ([Desafio 7](../desafio-07-discos-lvm-fstab/)) |
| **Acesso** | SSH com chave ([Desafio 9](../desafio-09-ssh-chave/)), usuário administrador |

---

## Conceitos

| Termo | Significa |
|---|---|
| **`tar`** | junta vários arquivos e pastas num único arquivo; com gzip, gera um `.tar.gz` compactado |
| **cron** | executa comandos em horários marcados; cada usuário tem a sua tabela, a **crontab** |
| **Timer do systemd** | alternativa moderna ao cron: o `.timer` diz **quando** rodar e o `.service` diz **o quê**. A saída vai para o journal, e o timer pode recuperar uma execução perdida |
| **Rotação** | apagar os backups antigos, para o disco não encher |

### cron x timer

| | cron | timer do systemd |
|---|---|---|
| Onde se configura | `crontab -e` | dois arquivos de unidade (`.service` e `.timer`) |
| Registro da execução | `/var/log/cron` mostra só que o comando rodou | o journal guarda a saída do script, o início e o fim |
| Servidor desligado na hora | a execução é perdida | com `Persistent=true`, roda assim que o servidor ligar |
| Próxima execução | não mostra | `systemctl list-timers` |

---

## Enunciado

Os dados do projeto "site" estão em `/srv/site` e `/dados/site`, e ninguém faz backup. É preciso criar um backup diário, primeiro com cron e depois migrando para um timer do systemd, e provar que o backup **restaura** corretamente, inclusive as permissões especiais.

### Objetivos

1. **Backup manual:** criar `/backup/site-teste.tar.gz` com `/srv/site` e `/dados/site`, compactado com gzip, preservando as **ACLs**, os **rótulos do SELinux** e as **permissões**. Listar o conteúdo sem extrair.
2. **Teste de restauração:** extrair o backup em `/tmp/restauracao` e provar que a ACL da Carla foi preservada.
3. **Script:** criar `/usr/local/bin/backup-site.sh`, que gera um backup com **data e hora no nome** e apaga os backups com mais de 7 dias.
4. **cron:** agendar o script na crontab do root para **todo dia às 02:30**, testando antes com um agendamento **a cada minuto**.
5. **Migrar para timer:** criar o `backup-site.service` e o `backup-site.timer` (todo dia às 02:30, recuperando a execução perdida) e **remover** o agendamento do cron.

### Resultado esperado

- `tar -tvf` lista o backup com as duas pastas.
- `getfacl` em `/tmp/restauracao/srv/site` mostra `user:carla:r-x`.
- No teste do cron, aparece um backup novo a cada minuto e o `/var/log/cron` registra as execuções.
- `systemctl list-timers` mostra a próxima execução às 02:30; `systemctl start backup-site.service` gera um backup; a crontab do root fica vazia.

---

## Preparação

```bash
sudo cp /etc/hosts /dados/site/teste-backup.txt
```

- Cria um arquivo de teste em `/dados/site`, para o backup ter o que guardar.

O Minimal Install não traz o `tar`:

```bash
dnf provides tar
sudo dnf install tar
rpm -q gzip
```

- O `rpm -q gzip` confere se o `gzip`, usado pela opção `-z`, está instalado.

---

## Passo a passo

### 1. Backup manual

```bash
sudo mkdir /backup
sudo tar --acls --selinux --xattrs -czpf /backup/site-teste.tar.gz /srv/site /dados/site
```

| Parte | Significa |
|---|---|
| `sudo` | o usuário administrador não tem acesso ao `/srv/site` (permissão `770`, grupo `site`) |
| `--acls` / `--selinux` / `--xattrs` | guardam as ACLs, os rótulos do SELinux e os atributos estendidos, onde os dois primeiros ficam armazenados |
| `-c` | **cria** um arquivo |
| `-z` | **compacta** com gzip |
| `-p` | preserva as permissões |
| `-f` | o próximo argumento é o **nome do arquivo**; por isso vem por último no grupo de letras |

**Resultado obtido:**

```
tar: Removendo "/" inicial dos nomes dos membros
tar: Removendo "/" inicial dos alvos de links físicos
```

O `tar` guarda os caminhos **sem** a barra inicial (`srv/site`). Assim, na extração, os arquivos vão para a pasta escolhida, e não por cima dos originais.

**Listar sem extrair:**

```
$ sudo tar -tvf /backup/site-teste.tar.gz
drwxrws--- root/site         0 2026-10-21 16:20 srv/site/
-rw-rw---- bruno/site        0 2026-10-21 13:50 srv/site/teste-bruno
-rw-rw---- bruno/site       28 2026-10-21 16:20 srv/site/teste2.txt
drwxr-xr-x root/root         0 2026-10-27 14:08 dados/site/
-rw-r--r-- root/root       436 2026-10-27 14:08 dados/site/teste-backup.txt
```

- `-t` lista; `-v` mostra os detalhes de cada item. Na leitura, o `tar` percebe sozinho que o arquivo está compactado.
- Os donos, as permissões e o setgid (`drwxrws---`) foram guardados. As ACLs não aparecem na lista: a prova é a restauração.

**Proteger o backup:**

```bash
sudo chmod 700 /backup
sudo chmod 600 /backup/site-teste.tar.gz
```

> ⚠️ O backup tinha nascido com `-rw-r--r--`: qualquer usuário poderia extrair uma cópia e ler arquivos do `/srv/site`, que é restrito ao grupo `site`. Backups devem ser tão protegidos quanto os dados originais.

### 2. Teste de restauração

```bash
sudo mkdir /tmp/restauracao
sudo tar --acls --selinux --xattrs -xzpf /backup/site-teste.tar.gz -C /tmp/restauracao
```

- `-x` **extrai**; `-C /tmp/restauracao` extrai dentro dessa pasta, e não na pasta atual.
- As opções `--acls --selinux --xattrs` precisam aparecer **também** na extração; sem elas, o `tar` não aplica o que guardou.

**Resultado obtido:**

```
$ sudo getfacl /tmp/restauracao/srv/site
# file: tmp/restauracao/srv/site
# owner: root
# group: site
# flags: -s-
user::rwx
user:carla:r-x
group::rwx
mask::rwx
other::---
default:user::rwx
default:user:carla:r-x
default:group::rwx
default:mask::rwx
default:other::---
```

A ACL da Carla (`user:carla:r-x` e `default:user:carla:r-x`) e o setgid (`flags: -s-`) voltaram com a restauração.

> ℹ️ O `/tmp` tem as permissões `drwxrwxrwt`. O `t` é o **sticky bit**: todos podem criar arquivos ali, mas cada um só pode apagar os próprios.

### 3. Script de backup

```bash
sudo vi /usr/local/bin/backup-site.sh
```

```bash
#!/bin/bash
umask 077
DESTINO=/backup
ARQUIVO=$DESTINO/site-$(date +%F_%H%M).tar.gz

tar --acls --selinux --xattrs -czpf "$ARQUIVO" /srv/site /dados/site

find "$DESTINO" -name 'site-*.tar.gz' -mtime +7 -delete
```

| Linha | O que faz |
|---|---|
| `umask 077` | os backups nascem com `600`, legíveis só pelo root (ver o [Desafio 2](../desafio-02-pasta-compartilhada/)) |
| `DESTINO=/backup` | cria uma **variável**; depois, `$DESTINO` é trocado por `/backup` |
| `$(date +%F_%H%M)` | executa o `date` e coloca o resultado no nome: data (`2026-10-27`) e hora (`1422`) |
| `"$ARQUIVO"` | a variável entre aspas, para não ser quebrada se o valor tiver espaços |
| `find ... -mtime +7 -delete` | **rotação**: apaga os backups modificados há mais de 7 dias |

```bash
sudo chmod 700 /usr/local/bin/backup-site.sh
```

- Só o root lê, edita e executa o script, que mexe em dados restritos.

**Teste manual:**

```
$ sudo /usr/local/bin/backup-site.sh
tar: Removendo "/" inicial dos nomes dos membros
tar: Removendo "/" inicial dos alvos de links físicos
$ sudo ls -l /backup
-rw-------. 1 root root 1081 out 27 14:22 site-2026-10-27_1422.tar.gz
-rw-r--r--. 1 root root 1100 out 27 14:10 site-teste.tar.gz
```

O backup do script nasceu com `-rw-------` por causa do `umask 077`; o `site-teste.tar.gz`, criado à mão antes da proteção, ainda estava com `-rw-r--r--`.

### 4. Agendar com cron

```bash
sudo crontab -e
```

- Abre a crontab do **root** no vi.

Teste a cada minuto:

```
* * * * * /usr/local/bin/backup-site.sh
```

| Campo | Significa | Valores |
|---|---|---|
| 1º | minuto | 0 a 59 |
| 2º | hora | 0 a 23 |
| 3º | dia do mês | 1 a 31 |
| 4º | mês | 1 a 12 |
| 5º | dia da semana | 0 a 7 (0 e 7 são domingo) |

O `*` quer dizer "qualquer valor".

**Resultado obtido (depois de alguns minutos):**

```
$ sudo ls -l /backup
-rw-------. 1 root root 1081 out 27 14:22 site-2026-10-27_1422.tar.gz
-rw-------. 1 root root 1081 out 27 14:24 site-2026-10-27_1424.tar.gz
-rw-------. 1 root root 1081 out 27 14:25 site-2026-10-27_1425.tar.gz
...
-rw-------. 1 root root 1081 out 27 14:30 site-2026-10-27_1430.tar.gz

$ sudo grep backup-site /var/log/cron
Oct 27 14:24:01 servidor1 CROND[66274]: (root) CMD (/usr/local/bin/backup-site.sh)
Oct 27 14:24:01 servidor1 CROND[66259]: (root) CMDEND (/usr/local/bin/backup-site.sh)
Oct 27 14:25:02 servidor1 CROND[66673]: (root) CMD (/usr/local/bin/backup-site.sh)
Oct 27 14:25:02 servidor1 CROND[66658]: (root) CMDEND (/usr/local/bin/backup-site.sh)
...
```

- `CMD`: o cron iniciou o comando. `CMDEND`: o comando terminou.
- O backup das 14:22 não aparece no log porque foi o teste manual.

Horário definitivo:

```
$ sudo crontab -l
#todo dia às 02:30
30 2 * * * /usr/local/bin/backup-site.sh
```

- Linhas começando com `#` são comentários, ignorados pelo cron.

### 5. Migrar para um timer do systemd

**O serviço** (o quê):

```bash
sudo vi /etc/systemd/system/backup-site.service
```

```ini
[Unit]
Description=Backup do projeto site

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-site.sh
```

- `Type=oneshot`: o serviço roda uma tarefa e **termina**. Depois de cada execução, o `status` mostra `inactive (dead)`, e isso é o esperado.
- Sem `[Install]` e sem `Restart`: quem inicia esse serviço é o timer.

**O timer** (quando):

```bash
sudo vi /etc/systemd/system/backup-site.timer
```

```ini
[Unit]
Description=Agenda o backup diário do projeto site

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

| Opção | O que faz |
|---|---|
| `OnCalendar=*-*-* 02:30:00` | `ano-mês-dia hora:minuto:segundo`; o `*` vale "qualquer um" |
| `Persistent=true` | se o servidor estava desligado na hora, roda assim que ligar |
| `WantedBy=timers.target` | o target dos timers (equivalente ao `multi-user.target` dos serviços) |

**Conferir antes de ativar:**

```bash
systemd-analyze calendar "*-*-* 02:30:00"
sudo systemd-analyze verify /etc/systemd/system/backup-site.timer
```

- `calendar` mostra quando o horário vai disparar (`Next elapse`).
- `verify` confere o arquivo de unidade e aponta cada linha com problema. Sem mensagem, está certo.

**Ativar:**

```bash
sudo chmod 644 /etc/systemd/system/backup-site.service /etc/systemd/system/backup-site.timer
sudo systemctl daemon-reload
sudo systemctl enable --now backup-site.timer
```

- Quem é ativado é o **timer**, e não o serviço.

**Resultado obtido:**

```
Created symlink '/etc/systemd/system/timers.target.wants/backup-site.timer' → '/etc/systemd/system/backup-site.timer'.
```

**Remover o agendamento do cron**, para o backup não rodar duas vezes:

```bash
sudo crontab -e
```

- Apagar as duas linhas (no vi, `dd` em cada uma) e salvar.

---

## Testes

```
$ systemctl list-timers backup-site.timer
NEXT                        LEFT LAST PASSED UNIT              ACTIVATES
Wed 2026-10-28 02:30:00 -03  11h -         - backup-site.timer backup-site.service

$ sudo systemctl start backup-site.service
$ sudo ls -l /backup
...
-rw-------. 1 root root 1081 out 27 14:39 site-2026-10-27_1439.tar.gz
-rw-------. 1 root root 1100 out 27 14:10 site-teste.tar.gz

$ journalctl -u backup-site.service -e
out 27 14:39:49 servidor1.estudos.local systemd[1]: Starting backup-site.service - Backup do projeto site...
out 27 14:39:49 servidor1.estudos.local backup-site.sh[72773]: tar: Removendo "/" inicial dos nomes dos membros
out 27 14:39:49 servidor1.estudos.local backup-site.sh[72773]: tar: Removendo "/" inicial dos alvos de links físicos
out 27 14:39:49 servidor1.estudos.local systemd[1]: backup-site.service: Deactivated successfully.
out 27 14:39:49 servidor1.estudos.local systemd[1]: Finished backup-site.service - Backup do projeto site.

$ sudo crontab -l
$
```

- `NEXT` mostra a próxima execução; `LAST` fica vazio até o timer disparar pela primeira vez (o backup das 14:39 foi iniciado à mão).
- A saída do script aparece no journal, com o início e o fim do serviço.
- `Deactivated successfully` logo depois de rodar é o comportamento do `Type=oneshot`.
- A crontab do root está vazia: o backup agora roda só pelo timer.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `sudo: tar: comando não encontrado` | O pacote `tar` não vem no Minimal Install | `sudo dnf install tar` |
| `/tmp/restauracao/srv/site` não existia | A pasta não tinha sido criada e a extração não tinha sido rodada | Rodar o `mkdir` e o `tar -x ... -C /tmp/restauracao` |
| `Você não pode especificar mais do que uma das opções "-Acdtrux"` | A linha do `tar` no script ficou duplicada (`tar tar ...`); o segundo `tar` foi lido como as operações `t`, `a`, `r`, junto com o `c` | Deixar a linha uma vez só (no vi: `dd` e redigitar) |
| `non-existent unit timer.target` | Faltou o `s`: o nome certo é `timers.target` | `WantedBy=timers.target` e `systemctl disable` antes de reativar |
| `Failed to parse calendar specification ... OnCalendar=*-*-* 02:30:00` | Caractere invisível colado no lugar do espaço; o texto parecia certo | Digitar a linha à mão. `cat -A` mostra os caracteres escondidos |
| `Unknown key 'nCalendar'` | No vi, o primeiro `O` virou o comando "abrir linha acima", e não a letra | `I` para ir ao início da linha e digitar o `O` |
| `site-teste.tar.gz` com `-rw-r--r--` | Criado à mão, sem `umask 077` | `chmod 600` no arquivo e `chmod 700` em `/backup` |

---

## Resumo

- `tar -czpf` cria; `-tvf` lista; `-xzpf ... -C pasta` extrai. Com `--acls --selinux --xattrs` na criação **e** na extração, as permissões especiais são preservadas.
- Um backup só vale se restaura: testar a extração e conferir com `getfacl`.
- Backups devem ser protegidos como os dados originais (`umask 077`, `chmod 600`/`700`).
- cron: `crontab -e`, cinco campos de horário, registros em `/var/log/cron`.
- Timer: `.service` com `Type=oneshot` + `.timer` com `OnCalendar` e `Persistent`, ativado com `enable --now` no timer. `systemd-analyze calendar` e `verify` conferem antes; `list-timers` mostra a próxima execução.
- Ao migrar do cron para o timer, remover o agendamento antigo.
