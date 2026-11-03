# Desafio 2.5 — Bastion SSH: um único ponto de entrada

Quinto e último desafio da Fase 2 (Redes e segurança) da trilha de estudos: criar uma segunda VM, a `servidor2`, e fazer com que ela só seja acessível por SSH **passando pela `servidor1`** (o *bastion*), só com chave, sem senha e sem root.

**Método:** mudanças no SSH e no firewall sempre com uma sessão aberta (e o console do Hyper-V como plano B), testando cada passo do lado do Windows.

---

## Ambiente

| Item | Valor |
|---|---|
| **Cliente** | Windows (`192.168.50.1`), PowerShell com o OpenSSH do Windows |
| **Bastion** | `servidor1` (Rocky Linux 10.2), `192.168.50.10`, usuário `alice_estudo`, chave do Windows já autorizada no [Desafio 1.9](../../fase-1-linux/desafio-09-ssh-chave/) |
| **Servidor interno** | `servidor2` (Rocky Linux 10, instalação nova), `192.168.50.20`, usuário `a_servidor2` |
| **Redes do Hyper-V** | `Default Switch` (internet, DHCP) e `rede-estudos` (laboratório, `192.168.50.0/24`) |

```
Windows ──SSH──► servidor1 (bastion) ──SSH──► servidor2
192.168.50.1     192.168.50.10                192.168.50.20
   └────────────── direto: bloqueado ─────────────╳
```

> Os IPs, usuários e o nome do comutador `rede-estudos` são os da minha máquina. Troque pelos seus ao refazer.

---

## Conceitos

| Termo | Significa |
|---|---|
| **Bastion** (ou *jump host*) | o único servidor exposto para acesso administrativo; os outros só aceitam conexões vindas dele. Um lugar só para proteger, vigiar e registrar |
| **`ProxyJump` / `ssh -J`** | o cliente abre um túnel **através** do bastion e autentica direto no destino. A chave privada **nunca** vai para o bastion |
| **`~/.ssh/config`** | "apelidos" de conexão no cliente: endereço, usuário e bastion de cada máquina |
| **Passphrase** | a senha que protege a chave privada **no seu PC**. O servidor nunca a vê |
| **`ssh-agent`** | guarda a chave destravada na memória, para digitar a passphrase uma vez só |
| **Rich rule** | regra do `firewalld` com condições, como "só deste IP de origem" |

---

## Enunciado

A `servidor2` vai guardar dados sensíveis. A política da empresa: ninguém acessa a `servidor2` direto das estações de trabalho; todo acesso passa pelo bastion; só chave SSH, nada de senha nem root.

### Objetivos

1. Fazer a **chave SSH do Windows** valer na `servidor2`.
2. Entrar na `servidor2` **passando pelo bastion** com um único comando, **sem copiar a chave privada para o bastion**.
3. Configurar o `~/.ssh/config` do Windows para que `ssh servidor2` funcione sozinho.
4. **Endurecer** o SSH da `servidor2`: sem senha e sem root.
5. **Firewall** da `servidor2`: SSH aceito **só** vindo do bastion.
6. **Provar** que o acesso direto falha, que pelo bastion funciona, e mostrar no log de qual IP a conexão veio.

**Bônus:** copiar um arquivo do Windows para a `servidor2` com `scp`, pelo bastion.

---

## Preparação: a segunda VM

### Memória do PC

Ao ligar a `servidor2` com 2048 MB:

```
Não é possível alocar 2048 MB de RAM: Não existem recursos de sistema suficientes para concluir o serviço solicitado. (0x800705AA).
```

```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
```

```
TotalVisibleMemorySize FreePhysicalMemory
---------------------- ------------------
              16076500             448816
```

Valores em KB: ~15,3 GB no total e só ~440 MB livres. No Gerenciador de Tarefas, o Chrome ocupava ~4 GB, e a `servidor1` (que não aparece como processo: a RAM das VMs é reservada direto pelo Hyper-V) tinha muito mais memória do que precisava.

**Solução:** `servidor1` reduzida para **1536 MB** (`sudo poweroff` → Configurações → Memória) e `servidor2` criada com **1536 MB**, mais o Chrome fechado. A `servidor1`, com Nginx e Apache, usa ~400 MB:

```
$ free -h
               total        used        free      shared  buff/cache   available
Mem:           1,4Gi       402Mi       999Mi       3,9Mi       126Mi       989Mi
Swap:          2,5Gi          0B       2,5Gi
```

### Criar a VM no Hyper-V

| Item | Valor |
|---|---|
| Nome | `servidor2` |
| Geração | **2** |
| Memória | **1536 MB**, sem memória dinâmica |
| Rede | `Default Switch` + um **segundo adaptador** em `rede-estudos` (Adicionar Hardware → Adaptador de Rede) |
| Disco | 20 GB |
| Instalação | ISO do Rocky Linux 10 |
| Segurança | Inicialização Segura com o modelo **"Autoridade de Certificação UEFI da Microsoft"** |
| Pontos de verificação | **"Usar pontos de verificação automáticos" desmarcado** |

Instalação: **Instalação mínima**, particionamento automático, usuário administrador (grupo `wheel`).

**Sem o modelo de Inicialização Segura certo**, a VM não dá boot pelo ISO:

```
1. SCSI DVD (0,1)
   The signed image's hash is not allowed (DB)
```

O modelo padrão, "Microsoft Windows", só aceita sistemas assinados pela Microsoft para o Windows. O carregador do Linux (*shim*) é assinado pela "Autoridade de Certificação UEFI da Microsoft".

### Nome e rede

Na instalação, o hostname ficou `localhost` e o segundo adaptador não tinha sido adicionado. Pelo console do Hyper-V:

```bash
sudo hostnamectl set-hostname servidor2.estudos.local
```

Depois de adicionar o adaptador em `rede-estudos`:

```
$ nmcli device status
DEVICE  TYPE      STATE                                   CONNECTION
eth0    ethernet  conectado                               eth0
eth1    ethernet  conectando (obtendo configuração de IP) Conexão cabeada 1
lo      loopback  connected (externally)                  lo
```

A `eth1` fica tentando DHCP, que não existe na `rede-estudos`. A `Conexão cabeada 1` é uma configuração automática e temporária, e o nome dela (espaço, `ç`, `ã`) é ruim de digitar. Em vez de modificá-la, foi criada uma conexão nova:

```bash
sudo nmcli connection add type ethernet ifname eth1 con-name eth1 ipv4.method manual ipv4.addresses 192.168.50.20/24
sudo nmcli connection up eth1
ping -c 3 192.168.50.10
```

| Parte | O que faz |
|---|---|
| `connection add type ethernet` | cria uma conexão cabeada |
| `ifname eth1` / `con-name eth1` | vale para a placa `eth1`; o nome da conexão também é `eth1` |
| `ipv4.method manual` + `ipv4.addresses 192.168.50.20/24` | IP fixo, sem DHCP; sem gateway, porque a internet sai pela `eth0` |

Quando passa a existir uma conexão de verdade para a `eth1`, a `Conexão cabeada 1` some sozinha.

---

## Passo a passo

### 1. A chave do Windows na `servidor2`

A chave da Fase 1 está no Windows:

```
PS> ls $env:USERPROFILE\.ssh
-a----        27/10/2026     13:18            464 id_ed25519
-a----        27/10/2026     13:18            105 id_ed25519.pub
-a----        27/10/2026     13:59           2854 known_hosts
```

O Windows não tem `ssh-copy-id`, então a chave **pública** vai em duas etapas. Do Windows:

```powershell
scp $env:USERPROFILE\.ssh\id_ed25519.pub a_servidor2@192.168.50.20:/tmp/
```

Primeira conexão: confirmar a impressão digital (`yes`) e digitar a **senha** do usuário (ainda não há chave). Na `servidor2`:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat /tmp/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
rm /tmp/id_ed25519.pub
```

| Comando | Por quê |
|---|---|
| `>>` | **acrescenta**; um `>` apagaria as chaves que já estivessem lá |
| `chmod 700` / `chmod 600` | com permissões abertas demais, o `sshd` ignora a chave |

Teste:

```
PS> ssh a_servidor2@192.168.50.20
Enter passphrase for key 'C:\Users\alice/.ssh/id_ed25519':
[a_servidor2@servidor2 ~]$
```

A pergunta é a **passphrase da chave** (conferida pelo próprio Windows), não a senha da `servidor2`: a autenticação por chave funcionou.

**`ssh-agent`**, para digitar a passphrase uma vez só. No PowerShell **como administrador** (o serviço vem desativado no Windows):

```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
```

No PowerShell normal:

```powershell
ssh-add
ssh-add -l
```

O agente do Windows continua com a chave depois de reiniciar o PC.

### 2. Pelo bastion com `ssh -J`

```
PS> ssh -J alice_estudo@192.168.50.10 a_servidor2@192.168.50.20
[a_servidor2@servidor2 ~]$ who
a_servidor2 tty1         2026-10-29 15:52
a_servidor2 pts/0        2026-10-29 15:56 (192.168.50.1)
a_servidor2 pts/1        2026-10-29 16:06 (192.168.50.10)
```

| Sessão | De onde | O que é |
|---|---|---|
| `tty1` | — | console do Hyper-V |
| `pts/0` | `192.168.50.1` | sessão direta do Windows (antes das restrições) |
| `pts/1` | **`192.168.50.10`** | sessão pelo bastion |

**Como o `-J` funciona:** o Windows abre SSH com o bastion e pede que ele encaminhe um túnel até a porta 22 da `servidor2`. Pelo túnel, o **Windows** autentica direto na `servidor2` com a chave que está no Windows. O bastion só repassa bytes cifrados e nunca vê a chave nem a passphrase. Para a `servidor2`, a conexão vem do bastion, e é isso que permite o firewall aceitar só o `192.168.50.10`.

> Alternativa **errada**: copiar a chave privada para o bastion e "pular" a partir dele. Se o bastion for invadido, a chave vai junto.

### 3. `~/.ssh/config` no Windows

```powershell
New-Item -ItemType File $env:USERPROFILE\.ssh\config
notepad $env:USERPROFILE\.ssh\config
```

`New-Item` cria o arquivo com o nome exato `config`, sem o risco de o Bloco de Notas salvar como `config.txt`.

```
Host servidor1
    HostName 192.168.50.10
    User alice_estudo

Host servidor2
    HostName 192.168.50.20
    User a_servidor2
    ProxyJump servidor1
```

| Linha | Significa |
|---|---|
| `Host` | o apelido usado no comando (`ssh servidor2`) |
| `HostName` | o endereço real |
| `User` | o usuário naquela máquina |
| `ProxyJump servidor1` | pular pelo bastion, usando o **apelido** definido acima: se o IP do bastion mudar, muda num lugar só |

Agora `ssh servidor1` e `ssh servidor2` entram direto, e o segundo passa pelo bastion.

### 4. SSH da `servidor2`: sem senha e sem root

```
$ sudo ls /etc/ssh/sshd_config.d/
40-redhat-crypto-policies.conf  50-redhat.conf
```

No Rocky 10, essa pasta só é legível pelo root (sem `sudo`: `Permissão negada`).

O `sshd` lê os arquivos em ordem alfabética e **o primeiro valor vence** ([Desafio 1.9](../../fase-1-linux/desafio-09-ssh-chave/)), por isso o nome começa com `00`:

```bash
sudo vi /etc/ssh/sshd_config.d/00-endurecimento.conf
```

```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

| Linha | O que faz |
|---|---|
| `PasswordAuthentication no` | desliga o login por senha |
| `KbdInteractiveAuthentication no` | desliga o modo interativo, outro caminho para pedir senha |
| `PermitRootLogin no` | ninguém entra como root, nem com chave |

```bash
sudo sshd -t
sudo systemctl reload sshd
sudo sshd -T | grep -E "passwordauthentication|kbdinteractive|permitrootlogin"
```

```
permitrootlogin no
passwordauthentication no
kbdinteractiveauthentication no
```

`sshd -t` testa a sintaxe (sem mensagem = ok); `sshd -T` mostra a configuração final, já juntando todos os arquivos.

**Prova** (do Windows, proibindo o uso da chave):

```
PS> ssh -o PubkeyAuthentication=no servidor2
a_servidor2@192.168.50.20: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

`password` e `keyboard-interactive` sumiram da lista de métodos aceitos. Os `gssapi-*` são login via Kerberos, que só funciona com um domínio configurado.

### 5. Firewall: SSH só vindo do bastion

```
$ sudo firewall-cmd --get-active-zones
public (default)
  interfaces: eth0 eth1
$ sudo firewall-cmd --list-services
cockpit dhcpv6-client ssh
```

**Ordem segura:** primeiro liberar o bastion, depois tirar a regra geral. Na ordem contrária, a própria sessão é cortada.

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.50.10" service name="ssh" accept'
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

| Parte | Significa |
|---|---|
| `rule family="ipv4"` | vale para IPv4 |
| `source address="192.168.50.10"` | só pacotes vindos do bastion |
| `service name="ssh"` | porta 22/tcp |
| `accept` | aceitar |
| `--remove-service=ssh` | tira o SSH liberado para todos |

```
public (default, active)
  interfaces: eth0 eth1
  services: cockpit dhcpv6-client
  rich rules:
        rule family="ipv4" source address="192.168.50.10" service name="ssh" accept
```

As **duas** placas estão na zona `public`, então a regra também fecha o caminho pelo `Default Switch` (`eth0`), que o Windows também alcança.

> O firewall bloqueia conexões **novas**; sessões já abertas antes da regra continuam funcionando até serem fechadas.

---

## Testes

**Direto pela rede do laboratório: bloqueado.**

```
PS> ssh a_servidor2@192.168.50.20
ssh: connect to host 192.168.50.20 port 22: Connection timed out
```

`timed out` = sintoma de firewall (catálogo do [Desafio 2.1](../desafio-01-caminho-requisicao/)): nenhuma resposta TCP voltou. Se fosse o serviço desligado, seria `Connection refused`, rápido.

**Direto pelo Default Switch: bloqueado.**

```
$ ip -br addr show eth0
eth0             UP             172.26.119.168/20 fe80::215:5dff:fe43:1a05/64

PS> ssh a_servidor2@172.26.119.168
ssh: connect to host 172.26.119.168 port 22: Connection timed out
```

O IP da `eth0` vem por DHCP e pode mudar quando o PC reinicia.

**Pelo bastion: funciona.**

```
PS> ssh servidor2
[a_servidor2@servidor2 ~]$
```

**O log mostra de onde cada login veio.**

```bash
sudo journalctl -u sshd --since "30 minutes ago" | grep Accepted
```

```
nov 03 10:29:39 ... Accepted password for a_servidor2 from 192.168.50.1 port 53111 ssh2
nov 03 10:29:39 ... Accepted password for a_servidor2 from 192.168.50.1 port 53112 ssh2
nov 03 10:32:22 ... Accepted publickey for a_servidor2 from 192.168.50.10 port 48804 ssh2: ED25519 SHA256:e6rdP4Z7pHL0km8R9M7edGeAJIiH/r3j8bYKlWn/9Y4
nov 03 10:33:24 ... Accepted password for a_servidor2 from 192.168.50.1 port 54743 ssh2
nov 03 10:33:24 ... Accepted password for a_servidor2 from 192.168.50.1 port 54744 ssh2
nov 03 10:55:59 ... Accepted publickey for a_servidor2 from 192.168.50.10 port 34104 ssh2: ED25519 SHA256:e6rdP4Z7pHL0km8R9M7edGeAJIiH/r3j8bYKlWn/9Y4
```

| Hora | Método | Origem | O que era |
|---|---|---|---|
| 10:29 e 10:33 (em dupla) | password | `192.168.50.1` | MobaXterm direto, **antes** das restrições. Em dupla porque o MobaXterm abre uma conexão para o terminal e outra para a barra SFTP |
| 10:32 | publickey | `192.168.50.10` | `ssh servidor2` pelo bastion |
| *~10:36* | | | *endurecimento do `sshd` e firewall aplicados* |
| 10:55 | publickey | `192.168.50.10` | `ssh servidor2` pelo bastion |

Depois das mudanças: nenhum login por senha e nenhum vindo do `192.168.50.1`. O `ED25519 SHA256:...` identifica a chave usada (no Windows, `ssh-keygen -lf $env:USERPROFILE\.ssh\id_ed25519.pub` mostra o mesmo valor).

**Bônus: `scp` pelo bastion.**

```powershell
"teste do bastion" | Out-File $env:USERPROFILE\teste.txt
scp $env:USERPROFILE\teste.txt servidor2:/tmp/
```

O apelido `servidor2` já inclui o `ProxyJump`, então o `scp` também passa pelo bastion sem nenhuma opção extra.

**MobaXterm pelo bastion:** na sessão da `servidor2` → **Network settings** → **SSH gateway (jump host)** → `192.168.50.10`, usuário `alice_estudo`.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `Não é possível alocar 2048 MB de RAM ... (0x800705AA)` | Só ~440 MB livres no PC: Chrome com ~4 GB e `servidor1` com memória de sobra | `servidor1` e `servidor2` com 1536 MB; Chrome fechado |
| Pergunta "Reverter o ponto de verificação automático" | O Hyper-V tirou uma "foto" da VM na tentativa que falhou | **Continuar** (reverter traria de volta os 2048 MB); desligar os pontos de verificação automáticos |
| `The signed image's hash is not allowed (DB)` | Inicialização Segura com o modelo "Microsoft Windows" | Modelo "Autoridade de Certificação UEFI da Microsoft" |
| Hostname `localhost` e sem `eth1` | Hostname não aplicado no instalador; segundo adaptador não adicionado | `hostnamectl set-hostname`; adicionar o adaptador em `rede-estudos` |
| `eth1` em `conectando (obtendo configuração de IP)` | Tentando DHCP numa rede sem DHCP | Conexão nova com IP fixo (`nmcli connection add ...`) |
| `ssh-add`: `Could not open a connection to your authentication agent` | Rodado dentro da `servidor2`, não no Windows | Rodar no PowerShell do Windows |
| `ls /etc/ssh/sshd_config.d/`: `Permissão negada` | No Rocky 10 a pasta é só do root | `sudo ls` |
| `hostname contains invalid characters` | O espaço reservado `<IP da eth0>` foi digitado literalmente | Trocar pelo IP real |
| `Out-File: comando não encontrado` | Comandos do PowerShell rodados no bash da `servidor2` | `exit` e rodar no Windows; conferir o prompt antes de cada comando |

---

## Resumo

- Bastion = um único ponto de entrada; os servidores internos só aceitam SSH vindo dele.
- `ssh -J` / `ProxyJump`: o cliente autentica direto no destino, através de um túnel. A chave privada nunca sai do PC.
- `~/.ssh/config` transforma `ssh -J alice_estudo@192.168.50.10 a_servidor2@192.168.50.20` em `ssh servidor2`, e vale também para o `scp`.
- Passphrase protege a chave no PC; `ssh-agent` evita digitá-la a cada salto.
- `sshd`: drop-in `00-...` em `sshd_config.d/` (o primeiro valor vence), `sshd -t` antes do `reload`, `sshd -T` para ver o resultado final.
- `firewalld`: rich rule com `source address` e `--remove-service=ssh`, **nessa ordem**. Conferir que **todas** as placas estão na zona.
- Provar do lado de fora (`timed out` pelas duas redes) e do lado de dentro (`journalctl -u sshd`, `who`).
- Segunda VM no Hyper-V: Geração 2 com o modelo de Inicialização Segura para Linux, memória dimensionada para o PC, e rede configurada com `nmcli`.
