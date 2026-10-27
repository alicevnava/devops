# Desafio 9 — SSH com Chave: Chega de Senha

Nono desafio da Fase 1 (Linux sólido) da trilha de estudos: trocar o login com senha no SSH por login com chave, instalar a chave à mão, conferir a identidade do servidor e configurar o servidor para recusar senhas.

**Método:** mudar uma coisa por vez, conferir antes de aplicar (`sshd -t`) e testar sempre numa sessão **nova**, mantendo a atual aberta.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | Rocky Linux 10.2 (Minimal Install), `servidor1.estudos.local`, IP fixo `192.168.50.10` ([Desafio 8](../desafio-08-rede/)) |
| **Cliente** | Windows, com o cliente OpenSSH (PowerShell) e o MobaXterm |
| **Usuário** | `alice_estudo`, administrador (grupo `wheel`) |

---

## Conceitos

O login com chave usa um **par** de arquivos:

| Arquivo | Onde fica | Pode compartilhar? |
|---|---|---|
| **Chave privada** (`id_ed25519`) | só no computador de quem acessa | **Nunca**. É como a chave da casa |
| **Chave pública** (`id_ed25519.pub`) | no servidor, em `~/.ssh/authorized_keys` | Sim. É como a fechadura |

Na conexão, o servidor desafia o cliente a provar que tem a chave privada que combina com a pública, **sem que a privada seja enviada pela rede**. A chave privada pode ser protegida por uma **frase secreta** (*passphrase*): mesmo que alguém copie o arquivo, não consegue usá-lo sem ela.

O servidor também tem as próprias chaves (`/etc/ssh/ssh_host_*`). Na primeira conexão, o cliente mostra a **impressão digital** (*fingerprint*) do servidor para que ela seja conferida, e a guarda em `known_hosts`.

---

## Enunciado

A equipe de segurança pediu que o servidor deixe de aceitar senhas no SSH. A partir de agora, o acesso deve ser feito só com chaves.

### Objetivos

1. **No Windows**, gerar um par de chaves do tipo **ed25519**, protegido por uma frase secreta.
2. Instalar a chave pública no servidor, para o usuário `alice_estudo`, **à mão** e com as permissões corretas.
3. Entrar no servidor pelo MobaXterm usando a chave.
4. Configurar o servidor para **recusar o login com senha** no SSH, para todos os usuários, e manter o **root** sem acesso.
5. Provar que o login com senha foi recusado e encontrar no journal o registro do login com chave.

### Resultado esperado

- Uma sessão nova do MobaXterm, configurada com a chave, entra pedindo só a frase secreta.
- `sudo sshd -T` mostra `passwordauthentication no`.
- Do Windows, `ssh ana@192.168.50.10` é recusado com `Permission denied (publickey...)`, sem pedir senha.
- O journal mostra `Accepted publickey for alice_estudo`.

### Regra de segurança

**Manter a sessão atual aberta** enquanto se mexe no SSH, e testar sempre numa sessão nova: a sessão já aberta continua funcionando mesmo que a configuração nova esteja errada. Se tudo der errado, o console da VM no Hyper-V (botão **Conectar**) não depende do SSH.

---

## Passo a passo

### 1. Gerar o par de chaves (no Windows)

No PowerShell:

```powershell
ssh-keygen -t ed25519 -C "<COMENTARIO>"
```

- `-t ed25519` escolhe o tipo de chave: moderno, curto e seguro.
- `-C` acrescenta um comentário no final da chave pública, para identificá-la (por exemplo, um e-mail ou o nome do computador).
- Aceitar o local padrão (Enter) e digitar uma **frase secreta**.

**Resultado esperado:** as mensagens `Your identification has been saved in C:\Users\<USUARIO>/.ssh/id_ed25519` e `Your public key has been saved in C:\Users\<USUARIO>/.ssh/id_ed25519.pub`.

> ℹ️ No Explorador de Arquivos, o `.pub` aparece com o ícone do Microsoft Publisher, que também usa essa extensão. O arquivo **sem** extensão é a chave privada.

### 2. Instalar a chave pública no servidor (à mão)

**No Windows**, mostrar a chave **pública**:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

- No PowerShell, `$env:USERPROFILE` é a pasta do usuário (`C:\Users\<USUARIO>`). No Prompt de Comando (cmd), usar o caminho completo: `type C:\Users\<USUARIO>\.ssh\id_ed25519.pub`.

**Resultado esperado:** **uma única linha** com três partes:

| Parte | Exemplo | Significa |
|---|---|---|
| tipo | `ssh-ed25519` | o tipo da chave |
| chave | `AAAAC3NzaC1lZDI1NTE5AAAA...` | a chave em si |
| comentário | `<COMENTARIO>` | só identifica a chave |

> ⚠️ Se aparecer `-----BEGIN OPENSSH PRIVATE KEY-----`, é a chave **privada**. Ela nunca deve ser copiada para outro lugar.

**No servidor**, como `alice_estudo` e **sem `sudo`** (os arquivos precisam pertencer ao usuário):

```bash
cd
mkdir -p ~/.ssh
chmod 700 ~/.ssh
vi ~/.ssh/authorized_keys
```

- No vi: `i`, colar a linha (no MobaXterm, botão direito ou **Shift+Insert**), `Esc` e `:wq`.

```bash
chmod 600 ~/.ssh/authorized_keys
restorecon -Rv ~/.ssh
```

- `700` na pasta e `600` no arquivo: só o dono acessa. O SSH **recusa** as chaves se a pasta ou o arquivo estiverem abertos demais, porque outra pessoa poderia colocar a chave dela ali e entrar como o usuário.
- `restorecon -Rv` garante o rótulo correto do SELinux na pasta e no arquivo. Sem nenhuma mensagem, os rótulos já estavam certos.

**Resultado obtido:**

```
$ ls -l ~/.ssh/authorized_keys
-rw-------. 1 alice_estudo alice_estudo 104 out 27 13:37 /home/alice_estudo/.ssh/authorized_keys
$ cat ~/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... <COMENTARIO>
```

### 3. Entrar com a chave pelo MobaXterm

Em uma **sessão nova**: **Session → SSH** → Remote host `192.168.50.10`, **Specify username** `alice_estudo` → aba **Advanced SSH settings** → **Use private key** → escolher `C:\Users\<USUARIO>\.ssh\id_ed25519` (o arquivo **sem** `.pub`).

**Resultado:** o MobaXterm pediu a **frase secreta**, e não a senha do Linux.

> ℹ️ Nas conexões seguintes, o MobaXterm entra sem pedir nada: o agente SSH interno dele (MobAgent) mantém a chave destravada enquanto o programa está aberto, e ele pode ter salvo a frase no gerenciador de senhas (**Settings → Configuration → General → MobaXterm passwords management**).

Para provar que a chave está protegida pela frase, testar pelo PowerShell, que não usa esse agente:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 alice_estudo@192.168.50.10
```

- `-i` indica qual chave privada usar.

Na primeira conexão, o cliente mostra a impressão digital do servidor:

```
The authenticity of host '192.168.50.10 (192.168.50.10)' can't be established.
ED25519 key fingerprint is SHA256:7EeDiLNhpOxgJqL4JSwFoUvwL/UnJ0B0SXOuqCIlFzo.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Antes de responder `yes`, conferir no servidor (numa sessão já aberta):

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

- `-l` mostra a impressão digital; `-f` indica o arquivo da chave pública **do servidor**.
- As duas impressões digitais devem ser iguais. Depois do `yes`, ela fica gravada em `known_hosts` e não é mais perguntada.

> ⚠️ Se um dia aparecer `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` para um servidor conhecido, não continuar sem descobrir o motivo: pode ser uma reinstalação ou alguém interceptando a conexão.

### 4. Recusar o login com senha

**Configuração em uso antes da mudança:**

```bash
sudo sshd -T | grep -i -E 'passwordauthentication|kbdinteractiveauthentication|permitrootlogin'
```

- `sshd -T` mostra a configuração **efetiva**: o resultado depois de ler todos os arquivos.
- `grep -i -E` filtra as três opções (`-i` ignora maiúsculas/minúsculas; `-E` permite o `|` como "ou").

| Opção | O que controla |
|---|---|
| `PasswordAuthentication` | login com senha |
| `KbdInteractiveAuthentication` | outra forma de pedir senha, pelo teclado. Se ficar ligada, a senha ainda pode ser pedida |
| `PermitRootLogin` | se o root pode entrar pelo SSH |

**A pegadinha da ordem dos arquivos:**

```
$ grep -i include /etc/ssh/sshd_config
Include /etc/ssh/sshd_config.d/*.conf
$ sudo ls /etc/ssh/sshd_config.d/
00-seguranca.conf  40-redhat-crypto-policies.conf  50-redhat.conf
```

- O `sshd_config` inclui, logo no início, os arquivos da pasta `sshd_config.d`, lidos em **ordem alfabética**.
- Para a maioria das opções, **vale o primeiro valor encontrado**. Um arquivo chamado `99-seguranca.conf` seria lido depois do `50-redhat.conf` e poderia ser ignorado. Por isso o nome começa com `00-`.

```bash
sudo vi /etc/ssh/sshd_config.d/00-seguranca.conf
```

```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

- `PermitRootLogin no` é mais rígido que o padrão do Rocky (`prohibit-password`, que deixa o root entrar só com chave).

> ℹ️ Os arquivos de configuração do SSH são legíveis só pelo root: para ver o conteúdo, `sudo cat`.

**Conferir a sintaxe antes de aplicar:**

```bash
sudo sshd -t
```

- Sem nenhuma mensagem: a sintaxe está certa. Se aparecer algo, corrigir antes de reiniciar.

**Aplicar:**

```bash
sudo systemctl restart sshd
```

As sessões já abertas continuam funcionando. Testar numa sessão **nova** antes de fechar as antigas.

---

## Testes

### Configuração efetiva

```
$ sudo sshd -T | grep -i -E 'passwordauthentication|kbdinteractiveauthentication|permitrootlogin'
permitrootlogin no
passwordauthentication no
kbdinteractiveauthentication no
```

### Login com senha recusado (no PowerShell)

```
PS> ssh ana@192.168.50.10
ana@192.168.50.10: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
PS> ssh root@192.168.50.10
root@192.168.50.10: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

Os dois foram recusados **sem pedir senha**. A lista entre parênteses mostra os métodos que o servidor oferece: `password` não aparece mais.

### Registros no journal

```
$ sudo journalctl -u sshd --since today | grep -i -E 'accepted|invalid|denied'
out 27 09:06:00 localhost.localdomain sshd-session[250479]: Accepted password for alice_estudo from 172.28.64.1 port 49231 ssh2
out 27 11:05:55 servidor1.estudos.local sshd-session[1764]: Accepted password for alice_estudo from 172.28.64.1 port 65451 ssh2
out 27 13:42:07 servidor1.estudos.local sshd-session[49974]: Accepted publickey for alice_estudo from 192.168.50.1 port 61711 ssh2: ED25519 SHA256:e6rdP4Z7pHL0km8R9M7edGeAJIiH/r3j8bYKlWn/9Y4
out 27 13:47:43 servidor1.estudos.local sshd-session[52239]: Invalid user alice_estudo2 from 192.168.50.1 port 53958
out 27 13:59:18 servidor1.estudos.local sshd-session[56650]: Accepted publickey for alice_estudo from 192.168.50.1 port 60025 ssh2: ED25519 SHA256:e6rdP4Z7pHL0km8R9M7edGeAJIiH/r3j8bYKlWn/9Y4
```

(trecho)

| O que mostra | Significa |
|---|---|
| `Accepted password ... from 172.28.64.1` | antes: login com senha, chegando pelo Default Switch |
| `Accepted publickey ... from 192.168.50.1` | depois: login com chave, chegando pela rede `rede-estudos` |
| `ED25519 SHA256:e6rd...` | a impressão digital da **chave do usuário** (diferente da do servidor, `SHA256:7EeD...`) |
| `Invalid user alice_estudo2` | tentativa com um usuário que não existe |

- Os logins aparecem em pares porque o MobaXterm abre duas conexões: o terminal e o navegador de arquivos da barra lateral.
- As tentativas recusadas de usuários **que existem** (`ana`, `root`) aparecem com outra mensagem, `Connection closed by authenticating user ... [preauth]`; para vê-las, filtrar por `preauth`.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `type $env:Users/alice\...` não funcionou | `$env:USERPROFILE` é o nome da variável e deve ser digitado assim; o PowerShell substitui pelo caminho | `type $env:USERPROFILE\.ssh\id_ed25519.pub` |
| `O sistema não pode encontrar o caminho especificado` | O texto `SEU_USUARIO` foi digitado literalmente; e no cmd o `$env:` não funciona | `type C:\Users\<USUARIO>\.ssh\id_ed25519.pub` |
| `Server refused our key` no MobaXterm | A sessão estava com o usuário `alice_estudo2`, que não existe (`Invalid user` no journal) | Corrigir o usuário da sessão para `alice_estudo` |
| `Identity file C:Usersalice.sshid_ed25519 not accessible` | O comando do Windows foi rodado **dentro do servidor**; o bash removeu as barras invertidas | Rodar no PowerShell do Windows |
| `cat` no `00-seguranca.conf` deu Permissão negada | Os arquivos de configuração do SSH são legíveis só pelo root | `sudo cat` |

---

## Resumo

- Login com chave: a chave privada fica só no cliente, protegida por frase secreta; a pública vai em `~/.ssh/authorized_keys` no servidor.
- Permissões: `~/.ssh` com `700` e `authorized_keys` com `600`, do próprio usuário; caso contrário, o SSH ignora a chave.
- Na primeira conexão, conferir a impressão digital do servidor com `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.
- Configuração própria em `/etc/ssh/sshd_config.d/`, com nome que venha **antes** dos arquivos do sistema (vale o primeiro valor encontrado).
- Sempre: `sshd -t` antes de reiniciar, `sshd -T` para ver o efetivo e teste numa sessão nova.
