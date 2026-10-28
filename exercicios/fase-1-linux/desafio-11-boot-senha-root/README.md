# Desafio 11 — Boot e Recuperação da Senha do Root: a Senha que Ninguém Lembra

Décimo primeiro e último desafio da Fase 1 (Linux sólido) da trilha de estudos: investigar o boot, interromper a inicialização pelo GRUB, trocar a senha do root sem saber a atual e garantir que o SELinux aceite a senha nova.

**Método:** trabalhar pelo **console da VM** (o SSH não existe nessa fase do boot), conferir cada passo antes de seguir e nunca desligar o SELinux.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), `servidor1.estudos.local` |
| **Virtualização** | Hyper-V, VM de Geração 2 |
| **Acesso** | **Console da VM** no Hyper-V (botão **Conectar**), e não SSH |

---

## Conceitos

O boot passa por estas etapas:

```
Firmware (UEFI) → GRUB (menu de boot) → kernel + initramfs → systemd → target (multi-user)
```

| Etapa | O que faz |
|---|---|
| **GRUB** | o menu que escolhe qual kernel iniciar, e com quais opções |
| **kernel** | o núcleo do Linux |
| **initramfs** | um mini-sistema temporário que prepara o disco e entrega o controle ao sistema de verdade |
| **systemd** | inicia os serviços até o **target** padrão (o "modo de operação") |

No GRUB, dá para alterar as opções do kernel para **um único boot**, sem mudar nenhum arquivo. É isso que permite recuperar a senha do root.

> ℹ️ Num servidor real, se algum administrador ainda consegue usar `sudo`, basta `sudo passwd root`. Este procedimento é para quando **ninguém** consegue entrar como administrador. Ele também mostra por que o acesso físico ao servidor, ou ao console das VMs, precisa ser protegido.

---

## Enunciado

O antigo administrador saiu da empresa e ninguém sabe a senha do root. É preciso recuperar o acesso sem reinstalar nada e sem desligar o SELinux.

### Preparação: simular o problema

Trocar a senha do root por uma desconhecida (por exemplo, colando duas vezes uma sequência aleatória no `sudo passwd root`) e confirmar com `su -`, que deve responder `Falha de autenticação`.

> ⚠️ Não usar `passwd -l` (bloquear a conta) para simular: com o root bloqueado, o terminal de emergência pode se recusar a abrir.

### Objetivos

1. Descobrir o **target padrão**, quanto tempo o último boot levou e o que mais o atrasou.
2. Deixar o **menu do GRUB** sempre visível.
3. **Recuperar a senha do root** pelo GRUB, interrompendo o boot.
4. Garantir que o **SELinux** aceite a senha nova.

### Resultado esperado

- `su -` (ou o login no console) entra com a senha nova do root.
- `ls -Z /etc/shadow` mostra `shadow_t`; `getenforce` mostra `Enforcing`.
- `journalctl --list-boots` mostra os boots feitos durante o desafio.

---

## Passo a passo

### 1. Investigar o boot

```
$ systemctl get-default
multi-user.target

$ systemd-analyze
Startup finished in 430ms (kernel) + 1.535s (initrd) + 2.900s (userspace) = 4.867s
multi-user.target reached after 1.929s in userspace.
```

- `get-default` mostra o target padrão: o modo de servidor, sem interface gráfica.
- `systemd-analyze` mostra o tempo de cada etapa. O firmware e o GRUB não aparecem porque o GRUB do Rocky não informa esses tempos ao systemd.

```bash
systemd-analyze blame | grep service
systemd-analyze critical-chain
```

- `blame` lista o tempo de inicialização de cada unidade. Sem filtro, o topo fica cheio de `.device` (discos e portas detectados no boot), que não são atrasos reais.
- `critical-chain` mostra a sequência que realmente determinou o tempo do boot.

**Trecho obtido:**

```
multi-user.target @1.929s
└─rsyslog.service @1.899s +28ms
  └─network-online.target @1.894s
    └─NetworkManager-wait-online.service @1.680s +212ms
      ...
                              └─swap.target @819ms
                                └─dev-disk-by\x2duuid-90f05007...swap
```

Na base da cadeia aparece a swap do [Desafio 7](../desafio-07-discos-lvm-fstab/): o boot esperou ela ficar pronta.

### 2. Deixar o menu do GRUB visível

```bash
sudo grub2-editenv - unset menu_auto_hide
sudo grub2-editenv list
```

- O Rocky esconde o menu quando o último boot deu certo. `unset menu_auto_hide` remove essa opção; `list` confere (a linha `menu_auto_hide` não deve aparecer).

Com o padrão de poucos segundos, foi difícil parar o menu no console do Hyper-V. Para ter tempo, o tempo de espera foi aumentado:

```bash
sudo vi /etc/default/grub          # GRUB_TIMEOUT=30
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

- O GRUB não lê o `/etc/default/grub` direto: lê o arquivo gerado pelo `grub2-mkconfig`.
- Depois do desafio, voltar para `GRUB_TIMEOUT=5` e gerar de novo.

### 3. Primeira tentativa: `rd.break`

No menu do GRUB: `e` na primeira entrada → setas até a linha que começa com `linux` → `Ctrl+E` (fim da linha) → acrescentar ` rd.break` → `Ctrl+X`.

- `rd.break` faz o boot parar dentro do initramfs.

**Resultado obtido:**

```
Entering emergency mode. Exit the shell to continue.
...
Give root password for maintenance
(or press Control-D to continue):
```

No Rocky Linux 10, o modo de emergência do initramfs **pede a senha do root**. Como no cenário ninguém sabe a senha, esse caminho não serve.

### 4. Método que funcionou: `init=/bin/bash`

Reiniciar a VM (**Ação → Redefinir** no console do Hyper-V; nesse ponto nada está aberto para escrita) e, no GRUB, acrescentar à linha `linux`:

```
 init=/bin/bash
```

- Em vez de iniciar o systemd, o kernel abre direto um terminal de root, **sem pedir senha**.

**Resultado obtido:** o prompt `bash-5.2#`.

> ℹ️ Se a `/` sair como outro caractere, o teclado está no padrão americano. No GRUB e nessa fase do boot, prefira letras e os números da **fileira de cima**: o teclado numérico pode funcionar como setas.

**No `bash-5.2#`, na ordem:**

```bash
mount | grep " / "            # confere: (ro,...) = só leitura
mount -o remount,rw /         # libera a escrita
passwd root                   # define a senha nova, sem pedir a atual
touch /.autorelabel           # pede a correção dos rótulos do SELinux no próximo boot
ls -la /.autorelabel          # confere se o arquivo foi criado
exec /sbin/init               # entrega o controle ao systemd e continua o boot
```

| Comando | O que faz |
|---|---|
| `mount -o remount,rw /` | o disco começa só para leitura (`ro`); passa a aceitar escrita (`rw`) |
| `passwd root` | troca a senha do root |
| `touch /.autorelabel` | se esse arquivo existir no boot, o sistema refaz os rótulos do SELinux de todos os arquivos e reinicia |
| `exec /sbin/init` | substitui o terminal pelo systemd, que continua o boot normal |

**Resultado esperado:** o boot continua, aparecem mensagens de *relabel* do SELinux, a VM **reinicia sozinha** e sobe até o `servidor1 login:`.

### 5. Por que o `/.autorelabel` é obrigatório

Nessa fase do boot, o SELinux não está carregado. O `passwd` recria o `/etc/shadow` (onde ficam as senhas), e o arquivo novo nasce **sem rótulo**:

```
bash-5.2# ls -Z /etc/passwd
system_u:object_r:passwd_file_t:s0 /etc/passwd
bash-5.2# ls -Z /etc/shadow
? /etc/shadow
```

Quando o sistema sobe com o SELinux em Enforcing, o programa de login não consegue ler um arquivo sem rótulo, e **todo** login falha com `Login incorrect`, inclusive com a senha certa. O *relabel* do próximo boot corrige isso.

---

## Testes

```
servidor1 login: root
Password:
Last failed login: Wed Oct 28 09:57:23 -03 2026 on tty1
There were 7 failed login attempts since the last successful login.

[root@servidor1 ~]# ls -Z /etc/shadow
system_u:object_r:shadow_t:s0 /etc/shadow
[root@servidor1 ~]# getenforce
Enforcing
[root@servidor1 ~]# journalctl --list-boots
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
...
 -6 b422304cf18649e1878b8dc5df06ab8e Wed 2026-10-28 09:28:38 -03 Wed 2026-10-28 09:32:19 -03
 -5 f25938f035ab496999e84cc12d77bc22 Wed 2026-10-28 09:32:22 -03 Wed 2026-10-28 09:35:22 -03
 -4 a7ab2423f1d64ca5be078b8f2eb8e417 Wed 2026-10-28 09:43:20 -03 Wed 2026-10-28 09:48:48 -03
 -3 92dd047c58624cfd9ce65a1cf0a7147a Wed 2026-10-28 09:49:31 -03 Wed 2026-10-28 09:56:46 -03
 -2 74a166007a3d4c2aa1de5bcbb220a48b Wed 2026-10-28 09:56:56 -03 Wed 2026-10-28 09:58:37 -03
 -1 e6b3cf56f042414ba43380cae999916c Wed 2026-10-28 10:00:18 -03 Wed 2026-10-28 10:07:13 -03
  0 60f77655d11649899ed71ad053f8f9a5 Wed 2026-10-28 10:07:17 -03 Wed 2026-10-28 10:08:10 -03
```

- O root entrou com a senha nova, o `/etc/shadow` tem o rótulo `shadow_t` e o SELinux continua em Enforcing.
- `7 failed login attempts`: as tentativas que falharam enquanto o arquivo estava sem rótulo e quando a senha foi digitada pelo teclado numérico.
- Os boots `-6` a `-2` são as tentativas com `rd.break` e `init=/bin/bash`; o `-1` é o do *relabel*, e o `0`, o reinício automático depois dele.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| O menu do GRUB passava antes de dar tempo de apertar uma tecla | Tempo de espera de poucos segundos | `GRUB_TIMEOUT=30` em `/etc/default/grub` + `grub2-mkconfig` |
| `Give root password for maintenance` com o `rd.break` | No Rocky 10, o modo de emergência do initramfs exige a senha do root | Usar `init=/bin/bash` |
| As VMs sumiram do Gerenciador do Hyper-V | Clique em **Remover Servidor**, que só tira o computador da lista do console | Fechar e abrir o Gerenciador do Hyper-V; nada foi apagado |
| `Login incorrect` para todos os usuários depois de trocar a senha | O `/etc/shadow` ficou sem rótulo do SELinux (`?` no `ls -Z`) e o `/.autorelabel` não tinha sido criado | Voltar ao `init=/bin/bash`, criar o `/.autorelabel` (conferindo com `ls -la`) e `exec /sbin/init` |
| `load_policy -i` não funcionou no `bash-5.2#` | Nessa fase, o ambiente não tem tudo que a política do SELinux precisa para carregar | Usar o `/.autorelabel`, que corrige no boot seguinte |
| A senha nova não funcionava no login | Os números foram digitados pelo **teclado numérico**, que no console pode funcionar como setas | Trocar de novo usando os números da fileira de cima, de preferência só letras e números |
| `passwd root` digitado no campo `login:` | O sistema já tinha continuado o boot; era a tela de login normal, e não o `bash-5.2#` | Conferir o prompt antes de digitar |

---

## Resumo

- Boot: firmware → GRUB → kernel + initramfs → systemd → target. `systemctl get-default`, `systemd-analyze` e `critical-chain` investigam o boot.
- O menu do GRUB fica visível com `grub2-editenv - unset menu_auto_hide`; o tempo de espera muda em `/etc/default/grub` + `grub2-mkconfig`.
- Recuperação da senha do root no Rocky 10: `init=/bin/bash` no GRUB → `mount -o remount,rw /` → `passwd root` → `touch /.autorelabel` → `exec /sbin/init`.
- Um arquivo alterado com o SELinux desligado fica sem rótulo; sem o *relabel*, o login falha mesmo com a senha certa.
- Quem tem acesso ao console consegue trocar a senha do root: o acesso físico e o console das VMs precisam ser protegidos.
