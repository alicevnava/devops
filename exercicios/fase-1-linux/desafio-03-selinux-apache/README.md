# Desafio 3 — SELinux: o Site que Não Abre

Terceiro desafio da Fase 1 (Linux sólido) da trilha de estudos: publicar um site no Apache e resolver um bloqueio do SELinux **sem desligá-lo**.

**Método:** ler o objetivo, pesquisar no `man`, testar uma coisa por vez e provar com testes que o resultado está certo.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), compatível com o RHEL 10 |
| **Virtualização** | Hyper-V, VM de Geração 2, 2 GB de RAM, 2 vCPUs, disco de 20 GB |
| **Acesso** | SSH pelo MobaXterm, com um usuário administrador criado na instalação |

---

## Enunciado

A equipe pediu um site simples no servidor. A página foi preparada na pasta pessoal de um usuário e depois movida para a pasta do Apache, mas o site dá erro. Depois, pediram que o site também respondesse na porta **8080**.

### Objetivos

1. Instalar o Apache (pacote `httpd`), iniciar o serviço e deixá-lo ativo no boot.
2. Criar o arquivo `index.html` **na pasta pessoal**, com o texto `Site da equipe`, e depois **mover** (com `mv`, não copiar) para `/var/www/html/`. Fazer o site abrir.
3. Fazer o Apache responder também na porta **8080**.

**Regra:** é proibido desligar o SELinux. Ele tem que continuar em modo **Enforcing** do começo ao fim.

### Resultado esperado

- `curl http://localhost` mostra `Site da equipe`.
- `curl http://localhost:8080` mostra `Site da equipe`.
- `getenforce` mostra `Enforcing`.

---

## Conceitos

### O que é o SELinux

O SELinux é uma camada extra de segurança do Red Hat e do Rocky Linux. Além das permissões comuns (`rwx`), ele dá um **rótulo** (chamado de *contexto*) a cada arquivo, processo e porta, e só deixa um processo acessar o que tem o rótulo certo para ele.

Uma comparação com um prédio:

| No prédio | No Linux |
|---|---|
| A fechadura da sala | as permissões comuns (`rwx`): quem tem a chave |
| O crachá do funcionário | o rótulo do programa: o Apache é `httpd_t` |
| A etiqueta na porta da sala | o rótulo do arquivo: conteúdo de site é `httpd_sys_content_t` |
| O segurança na porta | o SELinux: mesmo com a chave, só entra quem tem o crachá certo para aquela etiqueta |

**Por que existe:** se alguém invadir o Apache, o invasor fica preso ao rótulo `httpd_t`. Ele não consegue ler pastas pessoais, senhas ou qualquer coisa que não seja conteúdo de site, mesmo que as permissões comuns estejam erradas.

### O rótulo de um arquivo

O rótulo tem quatro partes separadas por `:`. A que mais importa é a terceira, o **tipo**, que termina em `_t`:

```
unconfined_u:object_r:user_home_t:s0
                      ^^^^^^^^^^^
                      tipo: "arquivo de pasta pessoal"
```

### `mv` x `cp`

| Comando | O que acontece com o rótulo |
|---|---|
| `mv` | move **o mesmo arquivo**, com o rótulo que ele já tinha |
| `cp` | cria **um arquivo novo**, que recebe o rótulo da pasta de destino |

> ⚠️ O `cp -a` copia preservando tudo, inclusive o rótulo. Nesse caso, o problema volta.

---

## Passo a passo

### 1. Instalar e iniciar o Apache

```bash
sudo dnf install httpd
```

- `dnf install` baixa e instala o pacote `httpd`, que é o Apache. Responda `y` na pergunta `Is this ok [y/N]:`.

```bash
sudo systemctl enable --now httpd
```

- `systemctl` controla os serviços do sistema.
- `enable` deixa o serviço ativo no boot, e `--now` já inicia agora.

### 2. Criar a página na pasta pessoal e mover para o Apache

```bash
cd ~
vi index.html
```

- `~` é um atalho para a pasta pessoal de quem está logado (por exemplo, `/home/alice_estudo`).
- No vi: `i`, digite `Site da equipe`, `Esc` e `:wq` + Enter.

```bash
ls -Z index.html
```

- O `-Z` mostra o rótulo do SELinux. O esperado é o tipo `user_home_t`, de arquivo de pasta pessoal.

```bash
sudo mv index.html /var/www/html/
```

### 3. Ver o problema

```
$ curl http://localhost
<title>403 Forbidden</title>
```

- `curl` faz uma requisição a um site e mostra a resposta no terminal.
- O **403 Forbidden** com permissões comuns corretas (`-rw-r--r--`) é um sinal clássico de bloqueio do SELinux.

### 4. Investigar o bloqueio no log

```bash
sudo ausearch -m avc -ts recent
```

- `ausearch` pesquisa o log de auditoria (`/var/log/audit/audit.log`), onde o SELinux registra os bloqueios.
- `-m avc` filtra só as mensagens de bloqueio do SELinux.
- `-ts recent` mostra só os últimos 10 minutos.

Saída obtida:

```
avc:  denied  { read } for  pid=183961 comm="httpd" name="index.html" dev="dm-0" ino=9302592
scontext=system_u:system_r:httpd_t:s0 tcontext=unconfined_u:object_r:user_home_t:s0 tclass=file permissive=0
```

Como ler:

| Trecho | Significa |
|---|---|
| `denied { read }` | o que foi bloqueado: uma leitura |
| `comm="httpd"` | quem tentou: o Apache |
| `name="index.html"` | o que ele tentou ler |
| `scontext=...httpd_t` | o rótulo de quem tentou (o processo do Apache) |
| `tcontext=...user_home_t` | o rótulo do que foi bloqueado (o arquivo) |

Para saber qual rótulo o arquivo deveria ter, compare com a própria pasta do Apache:

```
$ ls -Zd /var/www/html
system_u:object_r:httpd_sys_content_t:s0 /var/www/html
```

- `-d` mostra o próprio diretório, em vez do conteúdo dele.

### 5. Corrigir o rótulo

```bash
sudo restorecon -v /var/www/html/index.html
```

- `restorecon` devolve ao arquivo o rótulo que o SELinux define como padrão para aquele caminho. Em `/var/www/html`, o padrão é `httpd_sys_content_t`.
- `-v` mostra o que foi mudado.

**Resultado obtido:**

```
Relabeled /var/www/html/index.html from unconfined_u:object_r:user_home_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
```

### 6. Fazer o Apache escutar também na porta 8080

```bash
sudo vi /etc/httpd/conf/httpd.conf
```

Deixar as duas linhas `Listen`, sem `#` na frente:

```
Listen 80
Listen 8080
```

- No vi: `/Listen` + Enter procura a linha; `O` (maiúsculo) abre uma linha nova **acima** da atual.

```bash
sudo systemctl restart httpd
```

- Mudanças no `httpd.conf` só valem depois de reiniciar o serviço.

Para conferir:

```bash
systemctl status httpd
```

- Esperado: `enabled` na linha `Loaded` e `active (running)` na linha `Active`. Aperte `q` para sair da tela.

> ℹ️ O SELinux também controla em quais portas cada serviço pode escutar, mas a **8080 já faz parte das portas web liberadas** para o Apache. Por isso, aqui não foi preciso mudar nada no SELinux. Para uma porta fora dessa lista (por exemplo, a 82), seria necessário liberá-la com `semanage port`.

---

## Testes

```
$ getenforce
Enforcing
$ curl http://localhost
Site da equipe
$ curl http://localhost:8080
Site da equipe
```

O SELinux ficou em modo **Enforcing** durante todo o desafio.

### Para ver a diferença entre `mv` e `cp`

```bash
cd ~
echo "teste mv" > pagina2.html
sudo mv pagina2.html /var/www/html/
curl http://localhost/pagina2.html
```

- Esperado: **403 Forbidden**, porque o rótulo `user_home_t` foi junto. Corrige com `sudo restorecon -v /var/www/html/pagina2.html`.

```bash
echo "teste cp" > pagina3.html
sudo cp pagina3.html /var/www/html/
ls -Z /var/www/html/pagina3.html
curl http://localhost/pagina3.html
```

- Esperado: o arquivo copiado já nasce com `httpd_sys_content_t`, e o `curl` mostra `teste cp`, sem precisar do `restorecon`.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `curl http://localhost:8080` mostrava **403 Forbidden** | O `mv` levou o rótulo `user_home_t` junto com o arquivo, e o SELinux bloqueou a leitura pelo Apache | `sudo restorecon -v /var/www/html/index.html` |
| `curl http://localhost` dava `Could not connect to server` | A linha `Listen 80` foi **trocada** por `Listen 8080`, então ninguém escutava na porta 80 | Manter as duas linhas, `Listen 80` e `Listen 8080`, e reiniciar o Apache |
| O `ls -l` mostrava o `index.html` com tamanho `0` | O texto não tinha sido salvo no arquivo | Editar com `sudo vi` e salvar com `:wq` |
| `ls: não foi possível acessar 'var/www/html/index.html'` | Faltou a `/` no começo: sem ela, o caminho é procurado a partir da pasta atual | Usar o caminho absoluto, `/var/www/html/index.html` |

---

## Resumo

- O SELinux bloqueia acessos mesmo quando as permissões comuns estão certas.
- `ls -Z` mostra os rótulos; `ausearch -m avc` mostra o que foi bloqueado.
- Na linha `denied`, `scontext` é quem tentou e `tcontext` é o que foi bloqueado.
- `mv` mantém o rótulo antigo; `cp` cria o arquivo com o rótulo da pasta de destino.
- `restorecon` devolve o rótulo padrão para o caminho. Desligar o SELinux nunca é a solução.
