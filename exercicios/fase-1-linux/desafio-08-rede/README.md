# Desafio 8 — Rede no Servidor: o IP que Não Para Quieto

Oitavo desafio da Fase 1 (Linux sólido) da trilha de estudos: investigar a rede do servidor, definir um nome permanente, configurar um IP fixo numa segunda placa de rede, resolver nomes localmente e liberar o site no firewall.

**Método:** observar antes de mudar, mudar uma coisa por vez e conferir depois de cada passo. Nunca mexer na placa pela qual se está conectado.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), compatível com o RHEL 10 |
| **Virtualização** | Hyper-V, VM de Geração 2, com duas placas de rede |
| **Acesso** | SSH pelo MobaXterm, com um usuário administrador criado na instalação |
| **Ponto de partida** | Apache do [Desafio 3](../desafio-03-selinux-apache/) escutando nas portas 80 e 8080 |

---

## Conceitos

| Termo | Significa |
|---|---|
| **DHCP** | serviço que entrega endereços IP automaticamente. O Default Switch do Hyper-V usa DHCP e muda a faixa de endereços quando o Windows reinicia |
| **IP fixo** | endereço definido manualmente, que não muda. Servidores costumam ter IP fixo |
| **NetworkManager** | o serviço que controla a rede no Rocky. Sua ferramenta de linha de comando é o **`nmcli`** |
| **Conexão** | uma configuração de rede do NetworkManager, ligada a uma placa (*interface*), como a `eth0` |
| **`/etc/hosts`** | arquivo que liga nomes a IPs, consultado antes do DNS |
| **firewalld** | o firewall do Rocky, controlado pelo `firewall-cmd`. Organiza as regras em **zonas**; a padrão é a `public` |

### A solução: duas placas, duas funções

```
                 Windows (computador hospedeiro)
                 ┌──────────────────────────────┐
  internet ◄──── │ Default Switch (DHCP)        │ ◄── eth0  (IP muda; só para internet)
                 │                              │
  MobaXterm ───► │ rede-estudos 192.168.50.1    │ ──► eth1  192.168.50.10 (fixo)
                 └──────────────────────────────┘
```

---

## Enunciado

O servidor vai receber acessos da equipe, então precisa de um nome próprio e de um endereço que não mude. O site do Desafio 3 também precisa ficar acessível de outros computadores, e não só de dentro da própria VM.

### Objetivos

1. Descobrir a configuração atual da `eth0`: IP, máscara, gateway e servidores DNS.
2. Mudar o nome do servidor, de forma permanente, para **`servidor1.estudos.local`**.
3. Configurar a `eth1` com o IP fixo **`192.168.50.10/24`**, numa conexão chamada **`gerencia`**, ativa no boot, sem mexer na `eth0`.
4. Fazer o nome **`servidor1`** apontar para `192.168.50.10` no próprio servidor, sem usar um servidor DNS.
5. Liberar no **firewall**, de forma permanente, o acesso ao site nas portas 80 e 8080.

### Resultado esperado

- `hostnamectl` mostra `servidor1.estudos.local`.
- `ip a show eth1` mostra `192.168.50.10/24`.
- `ping -c 2 servidor1` responde a partir de `192.168.50.10`.
- No Windows, o navegador abre `http://192.168.50.10` e `http://192.168.50.10:8080`.
- Depois de reiniciar a VM, o MobaXterm conecta em `192.168.50.10` e tudo continua funcionando.

---

## Preparação no Windows e no Hyper-V

1. **Rede interna no Hyper-V:** Gerenciador de Comutador Virtual → Novo comutador de rede virtual → **Interno** → nome `rede-estudos`.
2. **IP fixo do Windows nessa rede:** Painel de Controle → Central de Rede e Compartilhamento → Alterar as configurações do adaptador → **vEthernet (rede-estudos)** → Propriedades → TCP/IPv4 → IP `192.168.50.1`, máscara `255.255.255.0`, sem gateway e sem DNS.
3. **Segunda placa na VM:** Configurações da VM → Adicionar Hardware → Adaptador de Rede → comutador `rede-estudos`.

---

## Passo a passo

### 1. Investigar a configuração atual

```bash
nmcli device show
```

- Mostra, para cada placa, o estado, a conexão, o IP, o gateway, as rotas e o DNS.

**Resultado obtido (trecho da `eth0`):**

```
GENERAL.DEVICE:                         eth0
GENERAL.STATE:                          100 (conectado)
GENERAL.CONNECTION:                     eth0
IP4.ADDRESS[1]:                         172.28.74.39/20
IP4.GATEWAY:                            172.28.64.1
IP4.ROUTE[2]:                           dst = 0.0.0.0/0, nh = 172.28.64.1
IP4.DNS[1]:                             172.28.64.1
IP4.DOMAIN[1]:                          mshome.net
```

| Item | Valor | Observação |
|---|---|---|
| IP e máscara | `172.28.74.39/20` | entregue por DHCP (`dynamic` no `ip a`) |
| Gateway | `172.28.64.1` | o Windows, pelo Default Switch. A rota `0.0.0.0/0` é a saída para a internet |
| DNS | `172.28.64.1` | também o Windows |

A `eth1`, recém-adicionada, aparecia como `desconectado`, sem IP.

### 2. Definir o nome do servidor

```bash
sudo hostnamectl set-hostname servidor1.estudos.local
```

- `hostnamectl` mostra e altera o nome da máquina. O `set-hostname` grava o nome permanente em `/etc/hostname`.
- O prompt só mostra o nome novo num login novo.

Antes, o `hostnamectl` mostrava `Static hostname: (unset)` e `Transient hostname: localhost`: o nome permanente nunca tinha sido definido.

### 3. Configurar o IP fixo na `eth1`

```
$ nmcli device status
DEVICE  TYPE      STATE                                    CONNECTION
eth0    ethernet  conectado                                eth0
eth1    ethernet  conectando (obtendo configuração de IP)  Conexão cabeada 1
lo      loopback  connected (externally)                   lo
```

O NetworkManager criou sozinho a `Conexão cabeada 1`, tentando pegar IP por DHCP numa rede que não tem DHCP.

```bash
sudo nmcli connection add type ethernet ifname eth1 con-name gerencia ipv4.method manual ipv4.addresses 192.168.50.10/24
```

| Parte | Significa |
|---|---|
| `connection add` | cria uma conexão nova |
| `type ethernet` | rede cabeada |
| `ifname eth1` | a placa em que a conexão vai ser usada |
| `con-name gerencia` | o nome da conexão |
| `ipv4.method manual` | IP definido manualmente, e não por DHCP |
| `ipv4.addresses 192.168.50.10/24` | o IP com a máscara |

- Sem gateway e sem DNS: a internet continua saindo pela `eth0`.
- Toda conexão criada pelo `nmcli` já vem ativa no boot.

```bash
sudo nmcli connection up gerencia
sudo nmcli connection delete "Conexão cabeada 1"
```

- `up` liga a conexão agora.
- A conexão automática foi apagada para não disputar a `eth1` com a `gerencia` no boot.

A conexão fica salva em `/etc/NetworkManager/system-connections/gerencia.nmconnection`.

### 4. Resolver o nome localmente

```bash
sudo vi /etc/hosts
```

Linha acrescentada ao final (IP, nome completo, apelido):

```
192.168.50.10   servidor1.estudos.local   servidor1
```

A ordem de consulta está em `/etc/nsswitch.conf`:

```
$ grep hosts /etc/nsswitch.conf
hosts:      files  dns myhostname
```

- `files` (o `/etc/hosts`) vem antes do `dns`.

> ℹ️ Essa linha vale só dentro da VM. No Windows, o acesso continua sendo pelo IP.

### 5. Liberar o site no firewall

O `curl http://localhost` funcionava dentro da VM porque `localhost` não passa pelo firewall. Pedidos vindos de outro computador passam, e o firewall bloqueia tudo o que não foi liberado.

```
$ sudo firewall-cmd --list-all
public (default, active)
  interfaces: eth0 eth1
  services: cockpit dhcpv6-client ssh
  ports:
```

- O `ssh` liberado é o que permite a conexão pelo MobaXterm.

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

- `--add-service=http` libera o serviço `http` (porta 80).
- `--add-port=8080/tcp` libera uma porta avulsa, informando o protocolo.
- `--permanent` grava a regra para valer depois do reboot, mas não aplica agora.
- `--reload` recarrega as regras permanentes e as aplica.

```
$ sudo firewall-cmd --list-all
public (default, active)
  interfaces: eth0 eth1
  services: cockpit dhcpv6-client http ssh
  ports: 8080/tcp
```

> ℹ️ O serviço `cockpit` continua liberado, embora o pacote tenha sido removido no Desafio 6. Boa prática: fechar o que não é usado, com `sudo firewall-cmd --permanent --remove-service=cockpit` e `--reload`.

---

## Testes (depois de `sudo reboot`, conectando pelo MobaXterm em `192.168.50.10`)

```
$ hostnamectl
     Static hostname: servidor1.estudos.local
    Operating System: Rocky Linux 10.2 (Red Quartz)

$ nmcli device status
DEVICE  TYPE      STATE                   CONNECTION
eth0    ethernet  conectado               eth0
eth1    ethernet  conectado               gerencia
lo      loopback  connected (externally)  lo

$ ip a show eth1
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    inet 192.168.50.10/24 brd 192.168.50.255 scope global noprefixroute eth1

$ ping -c 2 servidor1
PING servidor1.estudos.local (192.168.50.10) 56(84) bytes de dados.
64 bytes de servidor1.estudos.local (192.168.50.10): icmp_seq=1 ttl=64 tempo=0.030 ms
64 bytes de servidor1.estudos.local (192.168.50.10): icmp_seq=2 ttl=64 tempo=0.119 ms
2 pacotes transmitidos, 2 recebidos, 0% packet loss

$ sudo firewall-cmd --list-all
public (default, active)
  interfaces: eth0 eth1
  services: cockpit dhcpv6-client http ssh
  ports: 8080/tcp
```

- O prompt já aparece como `[alice_estudo@servidor1 ~]$`.
- A `eth1` subiu sozinha com a conexão `gerencia` e o IP fixo.
- As regras do firewall foram mantidas.
- No navegador do Windows, `http://192.168.50.10` e `http://192.168.50.10:8080` mostraram `Site da equipe`. ✅

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `hostname set-hostname ...` mostrou a ajuda do comando | O `hostname` é uma ferramenta antiga, que não tem o `set-hostname` | `sudo hostnamectl set-hostname servidor1.estudos.local` |
| A `Conexão cabeada 1` aparecia na `eth1` | Conexão automática do NetworkManager, tentando DHCP | `sudo nmcli connection delete "Conexão cabeada 1"` |
| `getnet: comando não encontrado` | Erro de digitação | `getent` |
| `fireall-cmd: comando não encontrado`, `unrecognized arguments: --ad-service` | Erros de digitação no comando e nas opções | Ler a mensagem: ela mostra exatamente a palavra que o comando não reconheceu |

---

## Resumo

- `nmcli device show` mostra IP, gateway, rotas e DNS de cada placa; `nmcli device status` e `nmcli connection show` mostram as conexões.
- `hostnamectl set-hostname` define o nome permanente do servidor.
- `nmcli connection add ... ipv4.method manual ipv4.addresses IP/máscara` cria uma conexão com IP fixo; `connection up` ativa.
- `/etc/hosts` resolve nomes localmente, antes do DNS (ordem definida em `/etc/nsswitch.conf`).
- `firewall-cmd --permanent` + `--reload` libera serviços e portas de forma permanente. `localhost` não passa pelo firewall; acessos externos passam.
