# Laboratório de Troubleshooting

Ambiente prático para treinar a identificação e a correção de falhas, simulando um incidente real.

**Método:** checar de fora para dentro — começar pelo que o usuário vê (navegador) e ir descendo camada por camada até achar a falha.

**Fluxo de trabalho:** investigar → localizar a falha → consertar → explicar.

---

## Arquitetura

Servidor Linux (Ubuntu) com uma aplicação em três camadas:

```
Navegador ──> Nginx (porta 80) ──> training-api (porta 3000) ──> PostgreSQL (porta 5432)
```

| Camada | O que é |
|---|---|
| **Nginx** | Servidor web de código aberto. Recebe a requisição do navegador e repassa para a API. Bom desempenho em alto tráfego. |
| **training-api** | Aplicação Node.js que responde em `/health` e `/api/items`. Busca os dados no banco. |
| **PostgreSQL** | Sistema gerenciador de banco de dados (SGBD) relacional, open source. Banco `training`, tabela `items`. |

---

## Pré-requisitos

- Uma instância EC2 Ubuntu com a aplicação já instalada (fornecida pelo instrutor do trainee).
- A chave privada SSH da instância (arquivo `.pem`).
- Um cliente SSH: MobaXterm ou Git Bash.

> ⚠️ A chave `.pem` **nunca** deve ser enviada para o GitHub.

### Como recriar a falha (para treinar de novo)

Se o ambiente já foi consertado e você quer refazer o lab, rode na instância:

```bash
sudo -u postgres psql -d training -c "REVOKE ALL ON items FROM training_app;"
sudo systemctl stop postgresql@16-main
```

- A primeira linha remove todas as permissões do usuário `training_app` na tabela `items` (falha 2).
- A segunda desliga o banco de dados (falha 1).

---

## Passo a passo

Nos comandos abaixo, troque `<IP_DA_INSTANCIA>` pelo IP público da sua instância.

### 1. Observar o problema no navegador

Abra `http://<IP_DA_INSTANCIA>` no navegador e pressione **F12** (DevTools) → aba **Network**.

**Resultado esperado:** a página abre, mas a lista de itens não carrega. A requisição para `/api/items` aparece com erro.

### 2. Conectar via SSH na instância

No Git Bash:

```bash
ssh -i lab.pem ubuntu@<IP_DA_INSTANCIA>
```

- `ssh`: abre uma conexão segura com outra máquina.
- `-i lab.pem`: usa essa chave privada para se autenticar.
- `ubuntu@...`: usuário `ubuntu` na máquina com esse IP.

No MobaXterm: **Session → SSH** → Remote host: `<IP_DA_INSTANCIA>` → Username: `ubuntu` → *Advanced SSH settings* → *Use private key* → selecionar o `.pem`.

**Resultado esperado:** o prompt muda para algo como `ubuntu@ip-...:~$`.

### 3. Verificar o status dos três serviços

```bash
sudo systemctl status nginx training-api postgresql@16-main --no-pager
```

- `systemctl status`: mostra se cada serviço está ligado ou desligado.
- `--no-pager`: mostra tudo de uma vez, sem precisar apertar `q` para sair.

**Resultado esperado:**

| Serviço | Estado |
|---|---|
| nginx | active (running) |
| training-api | active (running) |
| **postgresql@16-main** | **inactive (dead)** ❌ |

![Status dos serviços](img/01-status-servicos.png)

### 4. Testar cada camada

```bash
curl -v http://localhost:3000/health
```
Testa se a API (porta 3000) está viva. **Esperado:** resposta `200 OK`.

```bash
curl -v http://localhost:3000/api/items
```
Faz a API consultar o banco. **Esperado:** erro, porque o banco está desligado.

```bash
curl -v http://localhost/api/items
```
Testa se o Nginx (porta 80) repassa a requisição para a API. **Esperado:** o Nginx repassa, mas volta o mesmo erro do banco.

- `curl`: faz uma requisição HTTP pelo terminal.
- `-v`: modo detalhado, mostra cabeçalhos e código de resposta.

### 5. Ler os logs do banco

```bash
sudo journalctl -u postgresql@16-main.service -n 50 --no-pager
```

- `journalctl -u <serviço>`: mostra os logs daquele serviço.
- `-n 50`: só as últimas 50 linhas.

**Resultado esperado:** o serviço aparece como parado, sem mensagens de falha (`FATAL`, `Failed to start`, `error`). Ou seja, ele não quebrou: foi desligado.

### 6. Investigar a causa

```bash
pg_lsclusters
```
Lista os clusters do PostgreSQL. **Esperado:** versão 16, cluster `main`, porta 5432, status **down**.

```bash
sudo cat /etc/nginx/sites-enabled/*
```
Mostra a configuração ativa do Nginx. **Esperado:** o Nginx escuta a porta 80 e tem uma regra que repassa as requisições para a porta 3000. Configuração correta.

**Conclusão:** Nginx funcionando, API funcionando, PostgreSQL desligado.

### 7. Ligar o banco de dados — correção do ERRO 1

```bash
sudo systemctl start postgresql@16-main
```

Confirme:

```bash
pg_lsclusters
```

**Resultado esperado:** status **online**.

### 8. Repetir os testes do passo 4

```bash
curl -v http://localhost:3000/health
curl -v http://localhost:3000/api/items
curl -v http://localhost/api/items
```

**Resultado esperado:**
- `/health` → OK
- `/api/items` (direto e pelo Nginx) → `permission denied for table items` ❌

Apareceu um segundo problema.

![Permission denied](img/02-permission-denied.png)

### 9. Descobrir qual usuário a API usa no banco

```bash
sudo grep -iE "DB_|PG|DATABASE|user" /opt/training-api/server.js
```

- `grep`: procura texto dentro de um arquivo.
- `-i`: ignora maiúsculas e minúsculas.
- `-E "A|B|C"`: procura qualquer uma das palavras.

**Resultado esperado:** a API conecta no banco `training` com o usuário `training_app`.

### 10. Checar as permissões da tabela

```bash
sudo -u postgres psql -d training -c "\dp items"
```

- `sudo -u postgres`: roda o comando como o usuário `postgres`, o superusuário do banco (só ele vê e altera permissões).
- `psql -d training`: conecta no banco `training`.
- `-c "\dp items"`: mostra quem pode fazer o quê na tabela `items`.

**Resultado esperado:** a coluna de permissões está vazia. Só o dono (`postgres`) tem acesso; `training_app` não tem nenhuma permissão.

### 11. Conceder permissão — correção do ERRO 2

```bash
sudo -u postgres psql -d training -c "GRANT SELECT ON items TO training_app;"
```

- `GRANT SELECT`: dá permissão só de **leitura**. É o suficiente para a API listar os itens, sem poder inserir ou apagar (princípio do menor privilégio).

**Resultado esperado:** `GRANT`.

### 12. Confirmar a correção

```bash
sudo -u postgres psql -d training -c "\dp items"
```
**Esperado:** agora aparece `training_app=r/postgres` (`r` = read, leitura).

![Permissão aplicada](img/03-permissao-aplicada.png)

```bash
curl http://localhost:3000/api/items
curl http://localhost/api/items
```
**Esperado:** os dois retornam a lista de itens em JSON.

![API funcionando](img/04-api-items-ok.png)

### 13. Validar no navegador

Abra `http://<IP_DA_INSTANCIA>`.

**Resultado esperado:** a página carrega com a lista de itens.

![Página funcionando](img/05-pagina-web.png)

---

## Resumo das falhas

| # | Falha | Como foi encontrada | Correção |
|---|---|---|---|
| 1 | Banco desligado | `systemctl status` mostrou `inactive (dead)` | `sudo systemctl start postgresql@16-main` |
| 2 | Permissão faltando | `curl .../api/items` retornou `permission denied`; `\dp items` mostrou `training_app` sem acesso | `GRANT SELECT ON items TO training_app;` |

---

## Comandos úteis para troubleshooting

| Objetivo | Comando |
|---|---|
| Status dos serviços | `sudo systemctl status nginx training-api postgresql@16-main --no-pager` |
| Logs de um serviço | `sudo journalctl -u <serviço> -n 50 --no-pager` |
| API está viva? | `curl -v http://localhost:3000/health` |
| API fala com o banco? | `curl -v http://localhost:3000/api/items` |
| Nginx repassa certo? | `curl -v http://localhost/api/items` |
| Config do Nginx | `sudo cat /etc/nginx/sites-enabled/*` |
| Testar sintaxe do Nginx | `sudo nginx -t` |
| Código da API | `sudo cat /opt/training-api/server.js` |
| Dono e permissões de um arquivo | `ls -l <caminho>` |
| Permissões de uma tabela | `sudo -u postgres psql -d training -c "\dp <tabela>"` |
| Listar tabelas | `sudo -u postgres psql -d training -c "\dt"` |
| Listar bancos | `sudo -u postgres psql -l` |
| Cluster do Postgres está de pé? | `pg_lsclusters` |
| O que está escutando em cada porta | `sudo ss -tlnp` |
| Espaço em disco | `df -h` |
