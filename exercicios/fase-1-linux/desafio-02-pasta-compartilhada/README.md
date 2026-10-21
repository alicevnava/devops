# Desafio 2 — Pasta Compartilhada (Setgid, Umask e ACL)

Segundo desafio da Fase 1 (Linux sólido) da trilha de estudos. Continua o [Desafio 1](../desafio-01-usuarios-grupos-sudo/): o diretório `/srv/site` já existia, mas quem trabalhava nele não conseguia editar os arquivos dos colegas.

**Método:** ler o objetivo, pesquisar no `man`, testar uma coisa por vez e provar com testes que o resultado está certo.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), compatível com o RHEL 10 |
| **Virtualização** | Hyper-V, VM de Geração 2, 2 GB de RAM, 2 vCPUs, disco de 20 GB |
| **Acesso** | SSH pelo MobaXterm, com um usuário administrador criado na instalação |

### Ponto de partida (resultado do Desafio 1)

- Usuários `ana` e `bruno`, os dois no grupo `site`. A `ana` também está no grupo `wheel` (tem `sudo`).
- Diretório `/srv/site` com dono `root`, grupo `site` e permissão `770` (`drwxrwx---`).

---

## Enunciado

A Ana e o Bruno começaram a trabalhar em `/srv/site`, mas reclamaram: um não consegue editar os arquivos que o outro cria. Além disso, chegou a Carla, estagiária, que precisa **ler** os arquivos do projeto, mas não pode alterá-los nem entrar no grupo `site`.

### Objetivos

1. Todo arquivo novo criado em `/srv/site` deve pertencer automaticamente ao grupo `site`, e não ao grupo de quem o criou.
2. A Ana e o Bruno devem conseguir **editar** os arquivos um do outro.
3. A Carla (usuário `carla`) deve conseguir **ler**, mas não alterar, os arquivos de `/srv/site`, sem entrar no grupo `site`.

### Resultado esperado

- O `bruno` cria um arquivo novo, e o `ls -l` mostra o grupo `site`.
- A `ana` consegue escrever nesse arquivo.
- A `carla` consegue ver o conteúdo do arquivo com `cat`, mas recebe "Permissão negada" ao tentar alterá-lo.

---

## Conceitos

### Por que o problema acontecia

No Desafio 1, o arquivo criado pelo `bruno` ficou assim:

```
-rw-r--r--. 1 bruno bruno 0 out 21 13:50 teste-bruno
```

Dois motivos:

- **Grupo `bruno`:** por padrão, um arquivo novo recebe o grupo principal de quem o criou.
- **Grupo só com leitura (`r--`):** por causa da umask padrão, `022`.

### Umask

A umask é a **lista do que tirar** das permissões de um arquivo novo. Os três números seguem a ordem **dono, grupo, outros**, e cada um diz o que remover (`2` = tira a escrita, `0` = não tira nada).

Todo arquivo novo parte de `rw-rw-rw-` (`666`):

```
começa com:  rw-  rw-  rw-
umask 022:    -    -w   -w      (tira o w do grupo e dos outros)
resultado:   rw-  r--  r--   → 644
```

Com a umask `002`, o grupo mantém a escrita:

```
começa com:  rw-  rw-  rw-
umask 002:    -    -    -w      (tira o w só dos outros)
resultado:   rw-  rw-  r--   → 664
```

### Setgid em diretório

Com o bit **setgid** ativo num diretório, todo arquivo criado dentro dele herda o **grupo do diretório**, e não o grupo de quem o criou. Ele aparece como um `s` no lugar do `x` do grupo: `drwxrws---`.

### ACL (lista de controle de acesso)

As permissões comuns só têm três "vagas": dono, grupo e outros. A Carla não é dona, não está no grupo, e liberar "outros" liberaria para todo mundo. A ACL permite dar permissão a **um usuário específico**. Arquivos e diretórios com ACL aparecem com um `+` no final das permissões no `ls -l`.

A **ACL padrão** (*default*) de um diretório é herdada pelos arquivos criados dentro dele.

> ℹ️ Quando o diretório tem ACL padrão, o Linux usa as regras dela no lugar da umask para os arquivos criados ali.

---

## Passo a passo

### 0. Instalar os pacotes que faltam no Minimal Install

O Minimal Install não traz as ferramentas de ACL. Para descobrir qual pacote fornece um comando que não existe:

```bash
dnf provides getfacl
```

- `provides` mostra qual pacote contém o arquivo ou comando informado.

```bash
sudo dnf install acl
```

- `dnf install` baixa e instala o pacote. Responda `y` na pergunta `Is this ok [y/N]:`.

**Resultado esperado:** `Complete!` (ou `Concluído!`).

> ℹ️ O Minimal Install também vem só com o `vi`. Para ter o vim completo: `sudo dnf install vim-enhanced`.

### 1. Ativar o setgid no diretório

```bash
sudo chmod g+s /srv/site
```

- `g+s` adiciona (`+`) o bit setgid (`s`) ao grupo (`g`), sem mexer nas outras permissões.

**Resultado esperado:**

```
$ ls -ld /srv/site
drwxrws---. 2 root site 25 out 21 13:50 /srv/site
```

### 2. Configurar a umask da ana e do bruno

A umask vale por sessão. Para ficar permanente, ela vai no arquivo `.bashrc` de cada usuário, que é lido em todo login:

```bash
sudo vi /home/bruno/.bashrc
```

No vi:

1. `G` vai para a última linha.
2. `o` abre uma linha nova abaixo e entra no modo de inserção.
3. Digite `umask 002`.
4. `Esc` e `:wq` + Enter para salvar e sair.

Repita para `/home/ana/.bashrc`.

**Para conferir:** entre com o usuário (`su - bruno`) e rode `umask`. O resultado esperado é `0002`.

### 3. Criar a carla e dar a ela leitura com ACL

```bash
sudo useradd carla
sudo passwd carla
```

```bash
sudo setfacl -m u:carla:rx /srv/site
```

- `setfacl` define permissões de ACL; `-m` (de *modify*) adiciona ou altera uma regra.
- `u:carla:rx` significa "para o usuário `carla`, ler e entrar no diretório".

> ⚠️ Em um **diretório**, só o `r` não basta: ele permite ver a lista dos nomes, mas sem o `x` não dá para entrar nem abrir os arquivos.

```bash
sudo setfacl -d -m u:carla:rx /srv/site
```

- `-d` (de *default*) cria a regra como ACL padrão, herdada pelos arquivos novos. Nos arquivos, o Linux não aplica o `x`, então eles nascem só com leitura para a Carla.

**Resultado esperado:**

```
$ getfacl /srv/site
# file: srv/site
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

### 4. Ajustar o arquivo que já existia

O setgid, a umask e a ACL padrão só valem para arquivos **novos**. O `teste-bruno`, criado no Desafio 1, precisa ser ajustado manualmente:

```bash
sudo chgrp site /srv/site/teste-bruno
sudo chmod 660 /srv/site/teste-bruno
sudo setfacl -m u:carla:r /srv/site/teste-bruno
```

- `chgrp site` muda o grupo para `site`.
- `chmod 660` deixa dono e grupo com `rw-` (4 + 2 = 6) e os outros sem nada (0).
- `setfacl -m u:carla:r` dá leitura à Carla. Como é um arquivo, e não um diretório, não precisa do `x`.

---

## Testes

### Teste 0: configuração do diretório

```
$ ls -ld /srv/site
drwxrws---+ 2 root site 25 out 21 16:17 /srv/site
```

O `s` é o setgid e o `+` indica que há ACL.

### Teste 1: o bruno cria um arquivo e ele nasce com o grupo site

```
$ su - bruno
$ umask
0002
$ echo "linha do bruno" > /srv/site/teste2.txt
$ ls -l /srv/site/
-rw-rw----+ 1 bruno site  15 out 21 16:19 teste2.txt
$ exit
```

- `echo` escreve um texto, e o `>` manda esse texto para um arquivo, criando o arquivo se ele não existir.
- O arquivo nasceu com o grupo `site` e com escrita para o grupo.

### Teste 2: a ana edita o arquivo do bruno

```
$ su - ana
$ umask
0002
$ vi /srv/site/teste2.txt        (acrescentada a linha "linha da ana")
$ cat /srv/site/teste2.txt
linha do bruno
linha da ana
$ exit
```

### Teste 3: a carla lê, mas não altera

```
$ su - carla
$ cat /srv/site/teste2.txt
linha do bruno
linha da ana
$ echo "linha da carla" > /srv/site/teste2.txt
-bash: /srv/site/teste2.txt: Permissão negada
$ echo "linha da carla" >> /srv/site/teste2.txt
-bash: /srv/site/teste2.txt: Permissão negada
$ touch /srv/site/arquivo-carla
touch: não foi possível tocar '/srv/site/arquivo-carla': Permissão negada
$ exit
```

- `>` tentaria sobrescrever o arquivo e `>>` tentaria acrescentar uma linha no final. Os dois foram bloqueados.
- O `touch` tentaria criar um arquivo novo, também bloqueado.

### Teste 4: o arquivo antigo ficou igual aos novos

```
$ sudo ls -l /srv/site
-rw-rw----+ 1 bruno site 28 out 21 16:20 teste2.txt
-rw-rw----+ 1 bruno site  0 out 21 13:50 teste-bruno
```

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `getfacl: comando não encontrado` | O pacote `acl` não vem no Minimal Install | `sudo dnf install acl` |
| A `carla` recebia Permissão negada até para ler, e o `getfacl` não mostrava `user:carla` | O `setfacl` foi rodado antes de instalar o pacote e não foi repetido depois | Rodar de novo os dois `setfacl` |
| `umask` do bruno mostrava `0644` | Foi escrito `umask 644` no `.bashrc`, confundindo umask (o que tirar) com permissão (o que dar) | Trocar para `umask 002` |
| `chmod site arquivo` deu erro | `chmod` muda permissões; quem muda o grupo é o `chgrp` | `sudo chgrp site arquivo` |
| `chmod 420` deixou o arquivo com `r---w----` | Cada número é um **bloco inteiro** (dono, grupo, outros), não uma letra | `chmod 660`: dono `rw-` (6), grupo `rw-` (6), outros nada (0) |

---

## Observações

- **O `teste2.txt` nasceu com `-rw-rw----` e não `-rw-rw-r--`:** como o diretório tem ACL padrão com `default:other::---`, o Linux usou as regras da ACL no lugar da umask, e os "outros" ficaram sem acesso.
- **O usuário administrador também recebe Permissão negada ao listar `/srv/site` sem `sudo`:** ele não é dono, não está no grupo `site` e não tem ACL. Sem `sudo`, é um usuário comum.
