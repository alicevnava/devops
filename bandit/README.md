# Guia — OverTheWire: Bandit

Resolução comentada do wargame **Bandit** da [OverTheWire](https://overthewire.org/wargames/bandit/), feita durante meus estudos de infraestrutura/DevOps.

> ⚠️ A OverTheWire pede que as senhas não sejam divulgadas publicamente, para não estragar o jogo de outras pessoas. Elas estão aqui apenas como registro pessoal de estudo.

## Como conectar
- `ssh`: conecta a um servidor remoto
- `bandit0@...`: usuário do nível
- `2220`: porta do servidor

Ferramentas usadas: **MobaXterm** (terminal Linux no Windows) e o **Prompt de Comando (CMD)** do Windows, dependendo do nível.

---

## Bandit 0 → 1

**Enunciado:** a senha está em um arquivo chamado `readme`, na pasta inicial.

**Explicação:** primeiro contato com o Linux — listar arquivos e ler o conteúdo de um deles.

```bash
ls              # lista os arquivos da pasta
cat readme      # mostra o conteúdo do arquivo readme
```

**Senha obtida:** `6y2kwnwK6grgvwvpvLaa2T1cpFEKOhNR`

---

## Bandit 1 → 2

**Enunciado:** a senha está em um arquivo chamado `-` (um traço).

**Explicação:** um arquivo chamado `-` confunde os comandos, porque o traço costuma indicar uma opção (como em `-l`). Para o `cat` entender que é um arquivo, usamos o caminho `./-`.

```bash
ls
cat ./-         # o ./ deixa claro que - é um arquivo na pasta atual
```

**Senha obtida:** `PK8fYLZg2hnHSz83plBL1iEPKdD3QToB`

---

## Bandit 2 → 3

**Enunciado:** a senha está em um arquivo com espaços no nome.

**Explicação:** nomes com espaços precisam de **aspas**, senão o terminal entende cada palavra como um arquivo diferente.

```bash
ls
cat "spaces in this filename"
```

**Senha obtida:** `7ZZ2LFrykP2zEyvBl4m3clcL7tGYJPME`

---

## Bandit 3 → 4

**Enunciado:** a senha está em um arquivo **oculto** dentro da pasta `inhere`.

**Explicação:** no Linux, arquivos ocultos começam com ponto (`.`) e não aparecem no `ls` normal. O `ls -a` mostra todos, inclusive os ocultos.

```bash
ls
cd inhere       # entra na pasta inhere
ls -a           # -a mostra também os arquivos ocultos
cat ...Hiding-From-You
```

**Senha obtida:** `xzTXq1rDJQVVAzdv5cHq1TQytTWufAMq`

---

## Bandit 4 → 5

**Enunciado:** a senha está no único arquivo **legível por humanos** dentro de `inhere` (há vários `-file00` a `-file09`).

**Explicação:** o comando `file` diz o tipo de cada arquivo. Só um deles é texto (ASCII); os outros são dados binários.

```bash
ls
cd inhere
ls -la
file ./*        # mostra o tipo de todos os arquivos
cat ./-file07   # o único que era "ASCII text"
```

**Senha obtida:** `6C7h9GD8M6ai5nr7wo1RonrzFjj9yIrG`

---

## Bandit 5 → 6

**Enunciado:** a senha está em um arquivo dentro de `inhere` que é legível, tem **1033 bytes** e **não é executável**.

**Explicação:** com tantos arquivos e subpastas, usamos o `find` para buscar pelas características exatas.

```bash
ls
cd inhere
ls -la
find -readable -size 1033c    # legível e com 1033 bytes (c = bytes)
cat ./maybehere07/.file2
```

**Senha obtida:** `pXa26xhMWaC2SvDotA4r9EgZkulOeSBW`

---

## Bandit 6 → 7

**Enunciado:** a senha está em algum lugar do **servidor inteiro**: dono `bandit7`, grupo `bandit6`, tamanho **33 bytes**.

**Explicação:** o `find` busca a partir da raiz (`/`). O `2>/dev/null` descarta as mensagens de "Permission denied".

```bash
find / -user bandit7 -group bandit6 -size 33c 2>/dev/null
cat /var/lib/dpkg/info/bandit7.password
```

- `/`: procura no servidor todo
- `-user` / `-group`: filtra por dono e grupo
- `2>/dev/null`: joga os erros fora

**Senha obtida:** `Bmnnvf82KzQlfxgAI2d1zYbr1u9pr3E3`

---

## Bandit 7 → 8

**Enunciado:** a senha está em `data.txt`, ao lado da palavra `millionth`.

**Explicação:** o `grep` procura uma palavra dentro de um arquivo.

```bash
grep millionth data.txt
```

**Senha obtida:** `VR1ljMayciFxbnUokuQmJFw6QC9VKtub`

---

## Bandit 8 → 9

**Enunciado:** a senha é a única linha de `data.txt` que aparece **uma só vez**.

**Explicação:** o `sort` ordena as linhas (deixando as repetidas juntas) e o `uniq -u` mostra só as que não se repetem. O `|` (pipe) liga um comando ao outro.

```bash
sort data.txt | uniq -u
```

**Senha obtida:** `EjmOSvuAu7sGAHqHVcBDPirRe9T03kxl`

---

## Bandit 9 → 10

**Enunciado:** a senha está em `data.txt`, numa das poucas partes legíveis, precedida por vários `=`.

**Explicação:** o arquivo é binário; o `strings` extrai só os trechos legíveis, e o `grep` filtra os que têm `=`.

```bash
strings data.txt | grep ===
# alternativa:
cat data.txt | grep -a ==========
```

**Senha obtida:** `B0s2khmbT9u0geKuOoVGW3JZKhndE3BG`

---

## Bandit 10 → 11

**Enunciado:** `data.txt` contém dados em **base64**.

**Explicação:** base64 é uma forma de representar dados como texto (não é criptografia). O `-d` decodifica.

```bash
base64 -d data.txt
# alternativa:
cat data.txt | base64 -d
```

**Senha obtida:** `pYfOY6HwUsDj5rL9UvyhU7MCmv8vN5Ro`

---

## Bandit 11 → 12

**Enunciado:** em `data.txt`, as letras foram rotacionadas em 13 posições (**ROT13**).

**Explicação:** para desfazer o ROT13, basta girar mais 13. O `tr` troca caracteres seguindo a regra "primeiro grupo vira o segundo".

```bash
cat data.txt | tr 'A-Za-z' 'N-ZA-Mn-za-m'
```

**Senha obtida:** `GROozWPO8QyN0mGrjUkID0WCYkZiQxrN`

---

## Bandit 12 → 13

**Enunciado:** `data.txt` é um **hexdump** de um arquivo que foi compactado **várias vezes** seguidas.

**Explicação:** primeiro desfazemos o hexdump com `xxd -r`. Depois é um ciclo: `file` para descobrir o tipo, renomear com a extensão certa e descompactar. Repete-se até chegar no texto.

```bash
# Preparação
mktemp -d                  # cria uma pasta temporária
cd /tmp/tmp.XXXXX          # entra nela (use o caminho que apareceu)
cp ~/data.txt .            # copia o arquivo
xxd -r data.txt dados      # desfaz o hexdump

# 1ª volta - gzip
file dados
mv dados dados.gz
gzip -d dados.gz

# 2ª volta - bzip2
file dados
mv dados dados.bz2
bzip2 -d dados.bz2

# 3ª volta - gzip
file dados
mv dados dados.gz
gzip -d dados.gz

# 4ª volta - tar
file dados
mv dados dados.tar
tar -xf dados.tar
ls
mv data5.bin dados

# 5ª volta - tar
file dados
mv dados dados.tar
tar -xf dados.tar
ls
mv data6.bin dados

# 6ª volta - bzip2
file dados
mv dados dados.bz2
bzip2 -d dados.bz2

# 7ª volta - tar
file dados
mv dados dados.tar
tar -xf dados.tar
ls
mv data8.bin dados

# 8ª volta - gzip
file dados
mv dados dados.gz
gzip -d dados.gz

# Final
file dados                 # ASCII text
cat dados                  # mostra a senha
```

**Resumo das ferramentas:** `gzip -d` (.gz), `bzip2 -d` (.bz2), `tar -xf` (.tar). Sempre renomear antes de descompactar.

**Senha obtida:** `qQYQiHOBPR8zR61qxYqX45quvihF2uzk`

---

## Bandit 13 → 14

**Enunciado:** a senha do bandit14 só pode ser lida pelo próprio bandit14. Em vez da senha, você recebe uma **chave SSH privada**.

**Explicação:** a chave funciona como uma identidade: com `ssh -i`, você entra sem digitar senha. A chave estava no servidor, então é baixada para o computador com `scp`.

```bash
# No servidor (bandit13)
ls              # mostra sshkey.private
exit
```

```powershell
# No computador (PowerShell)
scp -P 2220 bandit13@bandit.labs.overthewire.org:sshkey.private .
# baixa a chave (pede a senha do bandit13)

# Só se der erro "UNPROTECTED PRIVATE KEY FILE":
icacls sshkey.private /inheritance:r
icacls sshkey.private /grant:r "${env:USERNAME}:R"

# Entrar como bandit14 usando a chave
ssh -i sshkey.private bandit14@bandit.labs.overthewire.org -p 2220
```

```bash
# Já como bandit14, ler a senha
cat /etc/bandit_pass/bandit14
```

- `scp`: copia arquivos via SSH (no scp a porta é `-P` maiúsculo)
- `icacls`: ajusta permissões no Windows (equivale ao `chmod`)
- `ssh -i`: entra usando uma chave

**Senha obtida:** `aaWecNkG4FhxJQxz07uiwzVP6bJiYS65`

---

## Bandit 14 → 15

**Enunciado:** envie a senha atual para a **porta 30000** do localhost.

**Explicação:** o `nc` (netcat) abre uma conexão de rede. Depois de conectar, cola-se a senha e aperta Enter.

```bash
nc localhost 30000
# colar a senha anterior e apertar Enter
```

**Senha obtida:** `pbLYuZtTg4MgaqfJx8jbA9gKKGqM68A7`

---

## Bandit 15 → 16

**Enunciado:** envie a senha para a **porta 30001** usando **SSL/TLS**.

**Explicação:** essa porta só aceita conexões criptografadas, então o `nc` comum não serve. O `ncat --ssl` faz a conexão segura.

```bash
ncat localhost --ssl 30001
# colar a senha anterior e apertar Enter
```

**Senha obtida:** `kS0Hf0u5HiXFwKMKFqXvPdOTNGGa0X8V`

---

## Bandit 16 → 17

**Enunciado:** encontre, entre as portas **31000–32000**, qual tem um servidor que fala SSL e devolve credenciais (as outras só repetem o que você envia). O resultado é uma **chave SSH**.

**Explicação:** o `nmap` descobre as portas abertas; depois testa-se cada uma com `openssl`. A chave recebida é salva no servidor com `vi` e baixada para o computador.

```bash
# No MobaXterm (bandit16)
nmap -p 31000-32000 localhost
openssl s_client -connect localhost:PORTA -quiet
# colar a senha anterior; a porta certa devolve a chave

mktemp -d
cd /tmp/tmp.XXXXX
vi bandit17.key     # colar a chave, salvar com :wq
cat bandit17.key
```

```powershell
# No PowerShell: baixar, proteger e entrar
scp -P 2220 bandit16@bandit.labs.overthewire.org:/tmp/tmp.XXXXX/bandit17.key .
icacls bandit17.key /inheritance:r
icacls bandit17.key /grant:r "${env:USERNAME}:R"
ssh -i bandit17.key bandit17@bandit.labs.overthewire.org -p 2220
```

> 💡 A chave criada no `vi` (dentro do Linux) evita problemas de formato que acontecem ao criá-la pelo Bloco de Notas do Windows.

**Senha obtida:** `pWXMAZoxGC8JmDMfmT5MGEsobMM3vnj2`

---

## Bandit 17 → 18

**Enunciado:** há dois arquivos, `passwords.old` e `passwords.new`. A senha é a **única linha que mudou** entre eles.

**Explicação:** o `diff` compara dois arquivos e mostra as diferenças. A linha que vem do `passwords.new` é a senha.

```bash
ls
diff passwords.new passwords.old
```

**Senha obtida:** `OQxXZjELndr90zuhOTDYBEomI0SZITXI`

---

## Bandit 18 → 19

**Enunciado:** a senha está no arquivo `readme`, mas o `.bashrc` foi alterado para te desconectar assim que você entra.

**Explicação:** o SSH permite rodar um comando direto, sem abrir o terminal interativo (e sem passar pelo `.bashrc`).

```bash
# No CMD do computador
ssh bandit18@bandit.labs.overthewire.org -p 2220 cat readme
```

**Senha obtida:** `KpsOfPkcP7i1FlIExk2QEjyt6dw8dxZI`

---

## Bandit 19 → 20

**Enunciado:** use o binário **setuid** da pasta inicial para ler a senha do bandit20.

**Explicação:** um programa com setuid roda com as permissões do **dono**, não de quem executa. Como ele pertence ao bandit20, consegue ler o arquivo protegido.

```bash
ls -l                                        # mostra o bandit20-do (com "s" nas permissões)
./bandit20-do                                # mostra como usar
./bandit20-do cat /etc/bandit_pass/bandit20  # roda o cat como bandit20
```

**Senha obtida:** `4pIjcunZ0fK2vmp3IwfG8Vf7VhxD6pOA`

---

## Bandit 20 → 21

**Enunciado:** um binário setuid se conecta a uma porta que você escolher, lê um texto e, se for a senha correta, devolve a próxima senha.

**Explicação:** aqui você cria o "servidor" com `nc -l` (que fica escutando) em um terminal, e roda o `suconnect` em outro. Precisa de **dois terminais**.

```bash
# Terminal 1 — cria o servidor e espera
nc -l -p 45678

# Terminal 2 — manda o programa se conectar
./suconnect 45678

# Terminal 1 — colar a senha anterior e apertar Enter
```

**Senha obtida:** `bW9kBv5WC3P4yoDyf12LSdGuNz5ka6hY`

---

## Bandit 21 → 22

**Enunciado:** um programa roda automaticamente via **cron**. Veja a configuração em `/etc/cron.d/`.

**Explicação:** o cron é o agendador de tarefas do Linux. O arquivo de configuração aponta para um script, que copia a senha para um arquivo em `/tmp`.

```bash
ls /etc/cron.d/
cat /etc/cron.d/cronjob_bandit22
cat /usr/bin/cronjob_bandit22.sh
cat /tmp/ARQUIVO_INDICADO_NO_SCRIPT
```

**Senha obtida:** `RYVux2rHEm9tiXHmLFzuR7Vhx6AZQMEz`

---

## Bandit 22 → 23

**Enunciado:** parecido com o anterior, mas o script gera o nome do arquivo com um **hash md5**.

**Explicação:** o script usa `whoami` (o nome do usuário que roda o cron, `bandit23`) para montar o nome do arquivo. Reproduzimos esse cálculo com `md5sum`.

```bash
cat /etc/cron.d/cronjob_bandit23
cat /usr/bin/cronjob_bandit23.sh
echo I am user bandit23 | md5sum      # gera o nome do arquivo
cat /tmp/CODIGO_QUE_APARECEU
```

> ⚠️ Use `bandit23` no echo, e não o seu usuário.

**Senha obtida:** `gKXDTAXnIz3OBxiPjRZ2uqutUlPZrBsw`

---

## Bandit 23 → 24

**Enunciado:** você precisa **criar seu próprio script**. O cron executa (como bandit24) tudo que está em `/var/spool/bandit24/foo/` e depois apaga.

**Explicação:** o script lê a senha do bandit24 e salva numa pasta sua. A pasta recebe `chmod 777` para o bandit24 conseguir escrever nela.

```bash
cat /etc/cron.d/cronjob_bandit24
cat /usr/bin/cronjob_bandit24.sh

mktemp -d
cd /tmp/tmp.XXXXX
chmod 777 .

vi script.sh
# conteúdo:
# #!/bin/bash
# cat /etc/bandit_pass/bandit24 > /tmp/tmp.XXXXX/senha.txt

chmod 777 script.sh
cp script.sh /var/spool/bandit24/foo/
# esperar até 1 minuto
ls
cat senha.txt
```

**Senha obtida:** `hVQMk3lJNsmQ7VF3ubyrNNBom7BOgVXv`

---

## Bandit 24 → 25

**Enunciado:** um daemon na **porta 30002** devolve a senha se receber a senha atual + um **PIN de 4 dígitos**. Só há como descobrir o PIN testando as 10000 combinações (**brute-force**).

**Explicação:** geramos todas as tentativas num arquivo e enviamos de uma vez pela mesma conexão. O `grep -v "Wrong"` remove as respostas erradas.

```bash
cat /etc/bandit_pass/bandit24
mktemp -d
cd /tmp/tmp.XXXXX

for i in {0000..9999}; do echo "COLE_A_SENHA_AQUI $i"; done > tentativas.txt
head tentativas.txt
wc -l tentativas.txt                                   # deve dar 10000

cat tentativas.txt | nc -q 2 localhost 30002 > resultado.txt
grep -v "Wrong" resultado.txt
```

- `for ... done`: repete para cada número de 0000 a 9999
- `-q 2`: faz o `nc` fechar 2 segundos após enviar tudo

**Senha obtida:** `SoHfqMOEqIX2IYKVciZxvgpR9a2Djx4P`

---

## Bandit 25 → 26 → 27

**Enunciado:** o shell do bandit26 não é o bash — ele te desconecta na hora. É preciso **escapar** dele.

**Explicação:** o shell abre um texto com o programa `more`. Se a janela do terminal for pequena, o `more` pausa e permite abrir o editor `vi` (tecla `v`). De dentro do `vi`, abre-se um shell normal. Em seguida, o setuid `bandit27-do` lê a senha do bandit27.

```bash
# No CMD do computador
cd %USERPROFILE%
scp -P 2220 bandit25@bandit.labs.overthewire.org:bandit26.sshkey .
# diminuir a janela do terminal (~5 linhas) ANTES de entrar
ssh -i bandit26.sshkey bandit26@bandit.labs.overthewire.org -p 2220

# com o --More-- na tela:
# apertar  v
# dentro do vi:
:set shell=/bin/bash
:shell

# agora como bandit26:
whoami
ls
./bandit27-do cat /etc/bandit_pass/bandit27
```

> ⚠️ Conexão de localhost para localhost é bloqueada, por isso o acesso é feito do computador, não de dentro do servidor.

**Senha obtida (bandit27):** `STJLJBRRphMxKB392CT4iOr5CbzPU9ER`

---

## Bandit 27 → 28

**Enunciado:** clone um repositório **git** e encontre a senha nele.

**Explicação:** `git clone` baixa uma cópia do repositório. A senha está direto no README.

```bash
git --version
cd %USERPROFILE%
git clone ssh://bandit27-git@bandit.labs.overthewire.org:2220/home/bandit27-git/repo
# senha = a do bandit27
cd repo
dir
type README
```

- `dir`: lista arquivos (o `ls` do Windows)
- `type`: mostra o conteúdo (o `cat` do Windows)

**Senha obtida:** `y8Yd2ssKcpHpud7UvOSOxwamRMzIGIeQ`

---

## Bandit 28 → 29

**Enunciado:** a senha está no **histórico** do repositório.

**Explicação:** o git guarda todas as versões (commits). Mesmo que a senha tenha sido "escondida" depois, ela continua no histórico. O `git log -p` mostra todas as mudanças.

```bash
cd %USERPROFILE%
git clone ssh://bandit28-git@bandit.labs.overthewire.org:2220/home/bandit28-git/repo repo28
cd repo28
type README.md
git log
git show
git log -p        # mostra as alterações de cada commit
```

**Senha obtida:** `Em7eGtqaMySwNFjCpwzzHhLhospOcdt0`

---

## Bandit 29 → 30

**Enunciado:** a senha está em outra **branch** (ramificação), não na principal.

**Explicação:** branches são linhas de trabalho paralelas. O `git branch -a` lista todas, e o `git checkout` troca entre elas.

```bash
cd %USERPROFILE%
git clone ssh://bandit29-git@bandit.labs.overthewire.org:2220/home/bandit29-git/repo repo29
cd repo29
type README.md
git branch -a       # lista todas as branches
git checkout dev    # muda para a branch dev
type README.md
```

**Senha obtida:** `jq9Dfg2rXsfYsWMgFuKlXhphjdH7USgX`

---

## Bandit 30 → 31

**Enunciado:** a senha está escondida em uma **tag**.

**Explicação:** tags são "etiquetas" que marcam pontos do repositório (geralmente versões). O `git tag` lista e o `git show` mostra o conteúdo.

```bash
cd %USERPROFILE%
git clone ssh://bandit30-git@bandit.labs.overthewire.org:2220/home/bandit30-git/repo repo30
cd repo30
type README.md
git log
git branch -a
git tag             # lista as tags
git show secret     # mostra o conteúdo da tag "secret"
```

**Senha obtida:** `82NkymblpGBYmIXG6ZQ8YldBYstHpfUf`

---

## Bandit 31 → 32

**Enunciado:** desta vez você precisa **enviar** (push) um arquivo `key.txt` com o conteúdo `May I come in?` para a branch master.

**Explicação:** o fluxo básico do git é `add` → `commit` → `push`. Há um `.gitignore` que ignora o `key.txt`, então usamos `-f` para forçar.

```bash
cd %USERPROFILE%
git clone ssh://bandit31-git@bandit.labs.overthewire.org:2220/home/bandit31-git/repo repo31
cd repo31
type README.md
echo May I come in?> key.txt     # sem espaço antes do >
type key.txt
git add -f key.txt               # -f força, ignorando o .gitignore
git status
git commit -m "add key"
git push                         # pede a senha; a resposta traz a senha nova
```

> ℹ️ O push é recusado de propósito (`pre-receive hook declined`) depois de devolver a senha — isso é esperado.

**Senha obtida:** `pWuj5jBQ6IgV0NXwiH6g1pXRF8S1YvbT`

---

## Bandit 32 → 33

**Enunciado:** o "UPPERCASE SHELL" transforma tudo que você digita em MAIÚSCULAS, quebrando os comandos.

**Explicação:** `$0` é o nome do próprio shell. Como é símbolo + número, não é afetado pela conversão para maiúsculas, e executa um shell novo e normal (como bandit33, por setuid).

```bash
$0
whoami
cat /etc/bandit_pass/bandit33
```

**Senha obtida:** `u4P2CyPOwPGLe94RdD9Uo2FxFwvnFswM`

---

## Conceitos praticados

| Tema | Comandos/ideias |
|------|-----------------|
| Navegação e arquivos | `ls`, `cd`, `cat`, `file`, arquivos ocultos |
| Busca | `find`, `grep`, `strings` |
| Pipes e redirecionamento | `\|`, `>`, `2>/dev/null` |
| Codificação/compressão | `base64`, `tr` (ROT13), `xxd`, `gzip`, `bzip2`, `tar` |
| Conexões | `ssh`, `scp`, `nc`, `ncat --ssl`, `openssl`, `nmap` |
| Permissões | `chmod`, setuid, dono e grupo |
| Automação | `cron`, scripts `.sh`, `md5sum` |
| Git | `clone`, `log`, `show`, `branch`, `checkout`, `tag`, `add`, `commit`, `push` |
