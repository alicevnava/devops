# Exercício: Publicar uma aplicação PHP em uma VM

Documentação do passo a passo realizado para publicar a aplicação `app-php`
em uma máquina virtual Linux, com Apache (httpd) e PHP.

## Ambiente utilizado

| Item | Valor |
|---|---|
| Distribuição | Oracle Linux Server |
| Versão | 10.2 |
| Gerenciador de pacotes | `dnf` |
| Web server | Apache (`httpd`) |
| Linguagem | PHP |
| Acesso à VM | SSH |

Para conferir a versão do sistema, foi usado:

```bash
cat /etc/os-release
```

---

## 1. Conectar na VM

```bash
ssh usuario@ip_da_vm
```

> Troque `usuario` e `ip_da_vm` pelos dados reais da sua VM.

---

## 2. Instalar o Git na máquina de trabalho (se ainda não tiver)

```bash
sudo dnf install git -y
```

---

## 3. Clonar o repositório do treinamento

```bash
git clone https://github.com/thiagoinacioalves/treinamento.git
cd ~/treinamento/Linux/app-php
```

---

## 4. Instalar o Apache e o PHP na VM

No Oracle Linux (base RHEL), o pacote do Apache se chama `httpd`. O PHP e o
módulo que integra o PHP ao Apache vêm em pacotes separados:

```bash
sudo dnf install httpd php php-cli -y
```

---

## 5. Habilitar e iniciar o Apache

O serviço precisa estar **habilitado** (inicia junto com o sistema) e
**ativo** (rodando agora):

```bash
sudo systemctl enable httpd
sudo systemctl start httpd
```

Conferir se está rodando corretamente:

```bash
sudo systemctl status httpd
```

---

## 6. Liberar a porta HTTP no firewall

O Oracle Linux usa `firewalld` por padrão. Sem isso, o navegador não consegue
alcançar a página mesmo com o Apache rodando:

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

---

## 7. Copiar a aplicação para a pasta pública do Apache

A pasta pública padrão do Apache no Oracle Linux é `/var/www/html`:

```bash
sudo cp -r ~/treinamento/Linux/app-php/* /var/www/html/
```

---

## 8. Ajustar posse (owner) e permissões dos arquivos

O Apache roda com o usuário `apache`. Os arquivos precisam pertencer a esse
usuário (ou pelo menos ser legíveis por ele):

```bash
sudo chown -R apache:apache /var/www/html
sudo chmod -R 755 /var/www/html
```

---

## 9. Ajustar o contexto do SELinux

O Oracle Linux vem com o SELinux em modo `enforcing` por padrão. Mesmo com a
permissão Unix correta, o Apache pode não conseguir ler os arquivos se o
contexto do SELinux estiver errado. Para corrigir:

```bash
sudo restorecon -Rv /var/www/html
```

Para conferir o contexto aplicado:

```bash
ls -Z /var/www/html
```

---

## 10. Acessar a aplicação pelo navegador

Descobrir o IP da VM (se ainda não souber):

```bash
ip a
```

Depois, no navegador da máquina de trabalho, acessar:

```
http://IP_DA_VM/index.php
```

**Resultado esperado:** a página exibe a mensagem
**"Página publicada com sucesso!"**, junto com informações do ambiente, do
software do servidor web e a data/hora geradas pelo servidor.

---

## 11. Testar que o PHP está sendo processado (e não servido como texto)

Se ao abrir `index.php` no navegador aparecer o **código PHP puro** em vez da
página renderizada, o PHP não está sendo processado pelo Apache — nesse caso,
reinicie o serviço depois de instalar o `php`:

```bash
sudo systemctl restart httpd
```

---

## 12. Fazer uma alteração simples e confirmar que é refletida

1. Editar o arquivo diretamente na pasta pública:

```bash
sudo nano /var/www/html/index.php
```

2. Alterar algum texto na página (por exemplo, uma mensagem de teste).
3. Salvar (`Ctrl+O`, `Enter`, `Ctrl+X` no nano).
4. Atualizar a página no navegador (F5) e confirmar que a alteração aparece.

---

## Caminho da requisição (navegador → arquivo)

1. O navegador faz uma requisição HTTP para o IP da VM.
2. O **Apache (httpd)**, que está escutando na porta 80, recebe a requisição.
3. O Apache identifica que o arquivo pedido é `.php` e encaminha o
   processamento para o **interpretador PHP**.
4. O PHP executa o código de `index.php` e gera um HTML como saída.
5. O Apache devolve esse HTML pronto para o navegador, que o exibe na tela.

---

## Checklist de conclusão

- [x] VM ligada e acessível pela rede
- [x] Apache (`httpd`) em execução e habilitado no boot
- [x] Porta HTTP liberada no firewall (`firewalld`)
- [x] PHP instalado e processado corretamente (sem aparecer como código-fonte)
- [x] Página exibe mensagem de sucesso e dados dinâmicos (data/hora do servidor)
- [x] Alteração no arquivo refletida após nova requisição
- [x] Owner (`apache:apache`) e permissões (`755`) ajustados
- [x] Contexto do SELinux corrigido com `restorecon`

## Estrutura do projeto

```
app-php/
├── index.php
└── README.md
```

<img width="1131" height="427" alt="image" src="https://github.com/user-attachments/assets/1294e16a-23b6-4e2c-b771-5aede3e45310" />

 ## Automação 
 O arquivo `deploy.sh` automatiza os passos 4 a 9 deste roteiro (instalação, habilitação do serviço, firewall, cópia dos arquivos, permissões e SELinux). Para usá-lo, dentro da VM: `chmod +x deploy.sh && sudo ./deploy.sh`.
 ! Não testado
