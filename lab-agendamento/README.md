# Laboratório de Agendamento (cron)

Fazer o Linux reiniciar o serviço do Docker sozinho, em um horário definido, e registrar em um arquivo de log:

- o horário de cada reinício;
- quando cada container voltou a rodar.

---

## Conceitos

| Termo | O que é |
|---|---|
| **cron** | Serviço do Linux que executa tarefas agendadas. |
| **cronjob** | Uma tarefa agendada. |
| **crontab** | A "tabela" de agendamentos. Cada usuário tem a sua. |
| **root** | Usamos o crontab do root porque ele tem permissão para reiniciar serviços e escrever em `/var/log`. |

### Formato de uma linha do crontab

```
*    *    *    *    *    comando
│    │    │    │    │
│    │    │    │    └── dia da semana (0-7; 0 e 7 = domingo)
│    │    │    └─────── mês (1-12)
│    │    └──────────── dia do mês (1-31)
│    └───────────────── hora (0-23)
└────────────────────── minuto (0-59)
```

- `*` significa "qualquer valor".
- `*/5` significa "a cada 5".

Ferramentas para montar e conferir expressões: [crontab.guru](https://crontab.guru/) e [rakko.tools](https://rakko.tools/pt/tools/cron-generator).

---

## Pré-requisitos

- Ubuntu com Docker instalado e containers rodando — este lab usa o ambiente do [Laboratório AWS com Docker](../lab-aws-docker) (pasta `~/aws-docker`).
- Acesso SSH com `sudo`.

---

## Fase 1 — Criar o script e testar

### 1.1 Ver o fuso horário da máquina

```bash
timedatectl
```
**Esperado:** `Time zone: Etc/UTC`. O cron usa o horário da máquina — em UTC, que está **3 horas à frente de Brasília**. Considere isso ao escolher um horário fixo.

### 1.2 Criar o script

```bash
sudo vim /usr/local/bin/restart-docker.sh
```
- `/usr/local/bin`: pasta padrão para scripts criados pelo administrador.

No vim: digite `:set paste` + Enter (para colar sem bagunçar a indentação) → `i` → cole o conteúdo do arquivo [`restart-docker.sh`](restart-docker.sh) desta pasta → `Esc` → `:wq` + Enter.

#### O que cada parte do script faz

| Trecho | O que faz |
|---|---|
| `#!/bin/bash` | *Shebang*: diz ao sistema que o arquivo deve ser executado pelo Bash |
| `LOG=/var/log/docker-restart.log` | Cria uma variável com o caminho do log (`/var/log` é a pasta padrão de logs) |
| `echo "$(date ...) - ..." >> "$LOG"` | Escreve uma linha com data e hora no log. `>>` **acrescenta** ao arquivo, sem apagar o que já existe |
| `systemctl restart docker` | Reinicia o Docker |
| `sleep 30` | Espera 30 segundos para os containers voltarem |
| `for c in $(docker ps -a --format '{{.Names}}')` | Repete o bloco para cada container |
| `docker inspect -f '{{.State.Status}}'` | Pega o estado do container (ex.: `running`) |
| `docker inspect -f '{{.State.StartedAt}}'` | Pega o horário em que o container iniciou — a prova de que reiniciou |

### 1.3 Conferir o script

```bash
cat /usr/local/bin/restart-docker.sh
```
**Esperado:** o conteúdo do script aparece igual ao do repositório.

### 1.4 Dar permissão de execução

```bash
sudo chmod +x /usr/local/bin/restart-docker.sh
```
- `+x`: torna o arquivo executável.

Confira:

```bash
ls -l /usr/local/bin/restart-docker.sh
```
**Esperado:** as permissões começam com `-rwxr-xr-x` (o `x` indica executável).

### 1.5 Executar manualmente (teste)

```bash
sudo /usr/local/bin/restart-docker.sh
```
**Esperado:** o terminal fica parado uns 30 segundos (por causa do `sleep`) e volta sem mensagem — tudo vai para o log.

### 1.6 Ler o log

```bash
cat /var/log/docker-restart.log
```
**Esperado:** uma linha "Reiniciando o servico docker", uma linha por container com `status: running` e o horário de início, e uma linha de traços no final.

![Log do teste manual](img/01-log-manual.png)

### 1.7 Confirmar que a aplicação voltou

```bash
cd ~/aws-docker
docker compose ps
```
**Esperado:** os três containers (`db`, `backend`, `frontend`) com status `Up`. Eles voltam sozinhos por causa do `restart: unless-stopped` no `compose.yml`.

---

## Fase 2 — Agendar no crontab

### 2.1 Ver o crontab atual do root

```bash
sudo crontab -l
```
**Esperado:** `no crontab for root` (ainda não há nada agendado).

### 2.2 Editar o crontab

```bash
sudo crontab -e
```
Na primeira vez, ele pergunta qual editor usar: digite o número da opção do **vim** (`/usr/bin/vim.basic`, normalmente a opção **2**) e Enter.

No vim: aperte `G` (vai para a última linha) → `o` (abre uma linha nova embaixo, já em modo inserção) → digite:

```
*/5 * * * * /usr/local/bin/restart-docker.sh
```
→ `Esc` → `:wq` + Enter.

- `*/5 * * * *`: a cada 5 minutos (intervalo curto, só para testar).
- Use sempre o **caminho completo** do script: o cron não conhece as mesmas pastas que o seu terminal.

**Esperado:** a mensagem `crontab: installing new crontab`.

### 2.3 Confirmar o agendamento

```bash
sudo crontab -l
```
**Esperado:** a linha `*/5 * * * * /usr/local/bin/restart-docker.sh` aparece no final.

### 2.4 Anotar a hora do servidor

```bash
date
```
Guarde o horário. A próxima execução será no próximo minuto múltiplo de 5 (ex.: 14:05, 14:10...). Depois disso, espere cerca de **40 segundos** (os 30 do `sleep` + margem).

### 2.5 Confirmar que o cron executou

```bash
journalctl -u cron --since "10 minutes ago"
```
- `journalctl -u cron`: logs do serviço cron.
- `--since "10 minutes ago"`: só os últimos 10 minutos.

**Esperado:** uma linha `(root) CMD (/usr/local/bin/restart-docker.sh)`.

### 2.6 Ver o log gerado pelo script

```bash
tail -n 10 /var/log/docker-restart.log
```
- `tail -n 10`: mostra as últimas 10 linhas do arquivo.

**Esperado:** um bloco novo com o horário do agendamento e os containers com `status: running`.

![Execução pelo cron](img/02-log-cron.png)

---

## Fase 3 — Pausar, apagar e restaurar

> Reiniciar o Docker a cada 5 minutos derruba a aplicação toda hora. Depois de validar, pause ou apague o agendamento.

### Opção A — Pausar só a linha

```bash
sudo crontab -e
```
Coloque um `#` no início da linha (vira comentário e não é executada):

```
#*/5 * * * * /usr/local/bin/restart-docker.sh
```

### Opção B — Pausar o serviço cron inteiro

```bash
sudo systemctl stop cron
systemctl is-active cron
```
**Esperado:** `inactive`. Isso para **todos** os agendamentos da máquina.

Para reativar:

```bash
sudo systemctl start cron
systemctl is-active cron
```
**Esperado:** `active`.

### Opção C — Apagar (com backup)

1. Fazer backup do crontab:

```bash
sudo crontab -l > ~/crontab-root.bak
ls -l ~/crontab-root.bak
```
- `>`: salva a saída do comando em um arquivo.

**Esperado:** o arquivo `crontab-root.bak` aparece com tamanho maior que zero.

2. Apagar o crontab do root:

```bash
sudo crontab -r
sudo crontab -l
```
**Esperado:** `no crontab for root`.

3. Restaurar a partir do backup:

```bash
sudo crontab ~/crontab-root.bak
sudo crontab -l | grep restart-docker
```
- `|`: envia a saída do primeiro comando para o segundo.
- `grep restart-docker`: filtra só a linha do script.

**Esperado:** a linha do agendamento aparece de novo.

---

## Exemplos de horários

| Expressão | Quando roda |
|---|---|
| `*/5 * * * *` | A cada 5 minutos |
| `0 * * * *` | De hora em hora, no minuto 0 |
| `0 6 * * *` | Todo dia às 06:00 UTC (03:00 em Brasília) |
| `0 6 * * 0` | Todo domingo às 06:00 UTC |
