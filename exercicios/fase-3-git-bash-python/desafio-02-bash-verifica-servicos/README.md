# Desafio 3.2 — Bash I: o verificador de serviços

Segundo desafio da Fase 3 (Git, Bash e Python) da trilha de estudos: o primeiro script em Bash, que verifica se os serviços do servidor estão no ar e responde com um **código de saída** que outro programa (agendamento, monitoramento) consegue entender. Entregue por pull request.

**Script final:** [`scripts/verifica-servicos.sh`](../../../scripts/verifica-servicos.sh)

**Método:** construir aos poucos (um serviço → vários → contagem → argumentos), testando o caminho de sucesso **e** o de falha a cada versão, sempre conferindo o `$?`.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), com Nginx, Apache (`httpd`) e SSH |
| **Repositório** | `~/repos/devops`, configurado no [Desafio 3.1](../desafio-01-git/) |

---

## Conceitos

| Termo | Significa |
|---|---|
| **Código de saída** | número que todo comando devolve ao terminar: **0 = sucesso**, qualquer outro = falha |
| **`$?`** | o código de saída do **último** comando |
| **Shebang** (`#!/bin/bash`) | primeira linha do script: qual programa executa o arquivo |
| **Variável** | `nome="valor"`, **sem espaços** ao redor do `=`; usada com `"$nome"` |
| **`if comando; then`** | roda o comando e decide pelo **código de saída** (0 → `then`) |
| **`[ ... ]`** | o comando `test`: compara e termina com 0 se a comparação for verdadeira |
| **`$#` / `$@`** | quantidade de argumentos / todos os argumentos |

---

## Enunciado

Toda manhã alguém entra no servidor e roda `systemctl status` serviço por serviço. O script deve fazer isso sozinho e terminar com **0** se tudo está no ar e **1** se algo caiu.

### Objetivos

1. Entender códigos de saída (`$?`) testando comandos à mão.
2. Escrever `scripts/verifica-servicos.sh`: shebang, comentário, permissão de execução.
3. Usar uma variável com a lista de serviços (`nginx httpd sshd`).
4. Percorrer a lista com `for` e testar cada um com `if`, mostrando `OK` ou `FALHOU`.
5. Contar as falhas e terminar com `exit 0` ou `exit 1`.
6. Provar os dois casos: tudo no ar e um serviço parado.
7. Entregar por pull request.

**Bônus:** aceitar a lista como argumento, usando a padrão quando nenhum for passado.

---

## Passo a passo

### 1. Branch

```bash
cd ~/repos/devops
git switch main
git pull
git switch -c script-verifica-servicos
```

### 2. Códigos de saída, à mão

```
$ systemctl is-active nginx
active
$ echo $?
0
$ systemctl is-active postfix
inactive
$ echo $?
4
$ systemctl is-active --quiet nginx
$ echo $?
0
```

| Comando | Código | Por quê |
|---|---|---|
| `is-active nginx` | 0 | ativo |
| `is-active postfix` | 4 | o `postfix` não está instalado: 4 = "unidade não existe". Um serviço instalado e parado dá 3 |
| `is-active --quiet nginx` | 0 | o `--quiet` não escreve nada, mas o código continua lá. É o que um script quer |

Para o script, a regra é o que importa: **0 é sucesso, o resto é falha**.

### 3. Primeira versão: um serviço

```bash
#!/bin/bash
# Verifica se os serviços do servidor estão no ar.

servico="nginx"

if systemctl is-active --quiet "$servico"; then
    echo "$servico: OK"
else
    echo "$servico: FALHOU"
fi
```

```bash
chmod +x scripts/verifica-servicos.sh
./scripts/verifica-servicos.sh
echo $?
```

| Parte | Por quê |
|---|---|
| `chmod +x` | sem permissão de execução: `Permissão negada` |
| `./` | o bash não procura programas na pasta atual, só no `PATH` |

Com `servico="postfix"`:

```
$ ./scripts/verifica-servicos.sh
postfix: FALHOU
$ echo $?
0
```

**O problema:** o script falhou, mas terminou com **0**. Sem `exit`, o código do script é o do **último comando** rodado, e o último foi o `echo`, que funcionou. Para quem chama o script, "está tudo bem": uma falha silenciosa.

### 4. Versão completa: vários serviços, contagem e `exit`

```bash
#!/bin/bash
# Verifica se os serviços do servidor estão no ar.
# Saída: 0 se todos estão ativos, 1 se algum falhou.

servicos="nginx httpd sshd"
if [ "$#" -gt 0 ]; then
    servicos="$@"
fi

falhas=0

for servico in $servicos; do
    if systemctl is-active --quiet "$servico"; then
        echo "$servico: OK"
    else
        echo "$servico: FALHOU"
        falhas=$((falhas + 1))
    fi
done

echo "Falhas: $falhas"

if [ "$falhas" -eq 0 ]; then
    exit 0
else
    exit 1
fi
```

| Trecho | O que faz |
|---|---|
| `servicos="nginx httpd sshd"` | lista padrão, separada por espaços |
| `if [ "$#" -gt 0 ]; then servicos="$@"; fi` | **(bônus)** se houver argumentos (`$#` > 0), eles substituem a lista padrão. `-gt` = maior que |
| `falhas=0` | contador |
| `for servico in $servicos; do ... done` | uma volta por nome. `$servicos` **sem aspas** de propósito, para o bash separar pelos espaços |
| `falhas=$((falhas + 1))` | aritmética de inteiros |
| `[ "$falhas" -eq 0 ]` | comparação numérica (`-eq` = igual). Espaços dentro dos colchetes são obrigatórios |
| `exit 0` / `exit 1` | o código de saída do script |

---

## Testes

**Tudo no ar:**

```
$ ./scripts/verifica-servicos.sh
nginx: OK
httpd: OK
sshd: OK
Falhas: 0
$ echo $?
0
```

**Apache parado:**

```
$ sudo systemctl stop httpd
$ ./scripts/verifica-servicos.sh
nginx: OK
httpd: FALHOU
sshd: OK
Falhas: 1
$ echo $?
1
$ sudo systemctl start httpd
```

**Com argumentos (bônus):**

```
$ ./scripts/verifica-servicos.sh nginx sshd
nginx: OK
sshd: OK
Falhas: 0
$ echo $?
0

$ ./scripts/verifica-servicos.sh nginx postfix
nginx: OK
postfix: FALHOU
Falhas: 1
$ echo $?
1
```

---

## Entrega por pull request

Linha nova na tabela do [`scripts/README.md`](../../../scripts/README.md), depois:

```bash
git status
git add scripts/README.md scripts/verifica-servicos.sh
git commit -m "Adiciona o script verifica-servicos.sh"
git push -u origin script-verifica-servicos
```

- `git status` mostrou `modified: scripts/README.md` (já acompanhado) e `Untracked: scripts/verifica-servicos.sh` (novo).
- O commit registrou `create mode 100755`: o Git guarda a **permissão de execução**. Quem clonar recebe o script executável (o README ficou `100644`).

No GitHub: **Create pull request** → **Merge pull request** → **Confirm merge** → conferir a etiqueta roxa **"Merged"** → só então **Delete branch**.

```bash
git switch main
git pull
git fetch --prune
git branch -d script-verifica-servicos
git log --oneline --graph -4
```

```
*   768ecde (HEAD -> main, origin/main, origin/HEAD) Merge pull request #3 from alicevnava/script-verifica-servicos
|\
| * b2a0053 Adiciona o script verifica-servicos.sh
|/
*   c59ab82 Merge pull request #2 from alicevnava/docs-desafio-3-1
```

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `echo $` mostrou só `$` | Faltou o `?` | `echo $?` |
| Script com `postfix: FALHOU` terminou com código 0 | Sem `exit`, vale o código do último comando (o `echo`) | `exit 0` / `exit 1` conforme o contador de falhas |
| A branch foi apagada no GitHub sem o merge; o `git branch -d` local avisou `not yet merged to HEAD` e apagou mesmo assim (o Git achou que a cópia do GitHub ainda existia) | **Delete branch** sem o **Merge** | O commit continuava na máquina: `git switch -c script-verifica-servicos b2a0053` (o hash vinha no `was b2a0053` do próprio aviso; sem ele, `git reflog`), novo push e novo PR, conferindo o **"Merged"** antes de apagar a branch |

---

## Resumo

- Todo comando devolve um código de saída: 0 = sucesso. `$?` mostra o do último comando.
- O `if` do Bash testa **se um comando deu certo**; `[ ... ]` é um comando de comparação (`-eq`, `-gt`).
- Variáveis: `nome="valor"` sem espaços; `"$nome"` com aspas ao usar.
- `for item in $lista; do ... done` percorre uma lista separada por espaços.
- Um script de verificação **precisa** terminar com `exit` explícito, senão esconde a falha.
- `$#` e `$@` deixam o script aceitar argumentos, com um padrão quando não há nenhum.
- No GitHub, **Merge** primeiro, **Delete branch** depois. Commit perdido se recupera pelo hash ou pelo `git reflog`.
