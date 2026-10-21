# Desafio 1 — Usuários, Grupos e Sudo

Primeiro desafio da Fase 1 (Linux sólido) da trilha de estudos: preparar um servidor para que duas pessoas trabalhem num projeto compartilhado, com acesso controlado por grupo e permissão de administrador só para quem precisa.

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

Chegaram duas pessoas novas na equipe, a Ana e o Bruno. Os dois vão trabalhar num projeto chamado "site". Prepare o servidor para eles.

### Objetivos

1. Criar os usuários `ana` e `bruno`, cada um com senha.
2. Criar um grupo `site` e colocar os dois nele.
3. Criar o diretório `/srv/site`, onde só quem é do grupo `site` pode ler e escrever.
4. Dar permissão de `sudo` só para a `ana`.

### Resultado esperado

- Logado como `bruno`, é possível criar um arquivo em `/srv/site`.
- Um usuário de fora do grupo não consegue nem listar o conteúdo de `/srv/site`.
- A `ana` consegue rodar um comando com `sudo`; o `bruno` não.

---

## Passo a passo

Todos os comandos abaixo foram executados com o usuário administrador, por isso usam `sudo`.

### 1. Criar os usuários e definir as senhas

```bash
sudo useradd ana
sudo useradd bruno
```

- `useradd` cria um usuário novo, com uma pasta pessoal em `/home` e um grupo com o mesmo nome dele.
- No Rocky Linux, o comando `adduser` é só um atalho para o `useradd` e funciona igual.

```bash
sudo passwd ana
sudo passwd bruno
```

- `passwd` define a senha do usuário informado. Ele pede a senha duas vezes e não mostra os caracteres digitados.

**Resultado esperado:** `passwd: senha atualizada com sucesso`.

> ℹ️ O Rocky tem uma política de senha que recusa senhas com menos de 8 caracteres ou que contenham o nome do usuário. Se aparecer `SENHA INCORRETA`, escolha uma senha mais forte.

### 2. Criar o grupo e colocar os usuários nele

```bash
sudo groupadd site
```

- `groupadd` cria um grupo novo.

```bash
sudo usermod -aG site ana
sudo usermod -aG site bruno
```

- `usermod` altera um usuário que já existe.
- `-G site` indica o grupo a adicionar.
- `-a` (de *append*) **adiciona** o grupo aos que o usuário já tem. Sem o `-a`, o comando substitui a lista inteira de grupos.

### 3. Criar o diretório do projeto e ajustar as permissões

```bash
sudo mkdir /srv/site
```

- `mkdir` cria um diretório. O `/srv` é o local padrão para dados de serviços oferecidos pelo servidor.

```bash
sudo chgrp site /srv/site
```

- `chgrp` muda o grupo dono do diretório de `root` para `site`.

```bash
sudo chmod 770 /srv/site
```

- `chmod` muda as permissões. Cada número representa um bloco, na ordem **dono, grupo, outros**, e é a soma de `r` (ler) = 4, `w` (escrever) = 2 e `x` (executar) = 1.
- `770` = dono `rwx` (7), grupo `rwx` (7), outros nada (0).

> ⚠️ Em um **diretório**, o `x` é a permissão de **entrar** nele. Sem o `x`, ninguém consegue criar nem acessar arquivos lá dentro, mesmo tendo `r` e `w`. Por isso "ler e escrever" num diretório, na prática, é `rwx`.

**Resultado esperado:**

```
$ ls -ld /srv/site
drwxrwx---. 2 root site 6 out 21 13:21 /srv/site
```

### 4. Dar permissão de sudo só para a ana

No Rocky Linux, quem pode usar `sudo` são os membros do grupo **`wheel`**. Isso está definido no arquivo `/etc/sudoers`, na linha que começa com `%wheel` (o `%` indica que a regra vale para um grupo):

```bash
sudo grep % /etc/sudoers
```

Então basta adicionar a `ana` ao grupo `wheel`, sem precisar editar o `/etc/sudoers`:

```bash
sudo usermod -aG wheel ana
```

---

## Testes

### Teste 1: grupos dos usuários

**Resultado esperado** (os números podem variar):

```
$ id ana
uid=1001(ana) gid=1001(ana) grupos=1001(ana),10(wheel),1003(site)
$ id bruno
uid=1002(bruno) gid=1002(bruno) grupos=1002(bruno),1003(site)
```

- `id` mostra o usuário, o grupo principal e todos os grupos de que ele faz parte.
- Os dois estão no grupo `site`, e só a `ana` está no `wheel`.

### Teste 2: o bruno consegue criar arquivo em /srv/site

```
$ su - bruno
$ touch /srv/site/teste-bruno
$ ls -l /srv/site
-rw-r--r--. 1 bruno bruno 0 out 21 13:50 teste-bruno
$ exit
```

- `su - bruno` troca para o usuário `bruno`, carregando o ambiente dele como se fosse um login novo.
- `touch` cria um arquivo vazio.

### Teste 3: quem é de fora do grupo não consegue listar

Para este teste, foi criado o usuário `carlos`, que não está no grupo `site`:

```
$ sudo useradd carlos
$ sudo passwd carlos
$ su - carlos
$ ls /srv/site
ls: não foi possível abrir o diretório '/srv/site': Permissão negada
$ exit
```

Aqui, o erro é o resultado certo.

### Teste 4: a ana tem sudo e o bruno não

```
$ su - ana
$ sudo whoami
root
$ exit

$ su - bruno
$ sudo whoami
bruno não está no arquivo sudoers.
$ exit
```

- `whoami` mostra com qual usuário o comando rodou. Com `sudo`, ele roda como `root`.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| O `bruno` recebia `Permissão negada` ao criar arquivo, e o diretório aparecia como `drwxrw----` | O `chmod` foi feito com `760`: o grupo ficou com `rw-`, sem o `x` para entrar no diretório | `sudo chmod 770 /srv/site` |
| A `ana` recebia `ana não está no arquivo sudoers` | Ela não estava no grupo `wheel` | `sudo usermod -aG wheel ana` |

> ℹ️ Mudanças de grupo só valem num login novo. Se um teste falhar logo depois de um `usermod`, saia do usuário com `exit` e entre de novo com `su -`.

---

## Para pensar

No Teste 2, o arquivo criado pelo `bruno` ficou com o grupo `bruno`, e não `site`, e com permissão só de leitura para o grupo. Ou seja, a `ana` não conseguiria editá-lo. Resolver isso, para que os arquivos novos herdem o grupo do diretório, é o assunto do [Desafio 2](../desafio-02-pasta-compartilhada/).
