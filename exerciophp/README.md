# Exercício: Publicar uma aplicação PHP em uma VM

Documentação do passo a passo realizado para publicar a aplicação `app-php`
em uma máquina virtual Linux, com Apache (httpd) e PHP.

Repositório: https://github.com/alicevnava/devops/tree/main/exerciophp

## Ambiente utilizado

| Item | Valor |
|---|---|
| Distribuição | Oracle Linux Server |
| Versão | 10.2 |
| Gerenciador de pacotes | `dnf` |
| Web server | Apache (`httpd`) |
| Linguagem | PHP |
| Acesso à VM | SSH |

---

## Comandos — passo a passo manual

**Verificar IP**
```bash
ip a
```
Utilizar no MobaXterm na sessão de SSH.

**Verificar versão e distribuição**
```bash
cat /etc/os-release
```

**Instalar Apache (servidor web), PHP e seu interpretador**
```bash
sudo dnf install httpd php php-cli -y
```
`-y`: confirma automaticamente.

**Ativar e rodar o Apache**
```bash
sudo systemctl enable httpd
sudo systemctl start httpd
```
`enable`: inicia o Apache quando a VM ligar.
`start`: inicia o Apache na sessão atual.

**Checar o estado e a saúde do Apache**
```bash
sudo systemctl status httpd
```
`q`: sai da tela de status.

**Liberar a porta HTTP (porta 80) no firewall, para o navegador conseguir acessar**
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

**Clonar os arquivos de código**
```bash
git clone https://github.com/alicevnava/devops.git
```
Se já tiver a pasta e for excluir (sem volta):
```bash
rm -rf devops
```

**Rede com autenticação (proxy/certificado)**
```bash
git config --global http.sslVerify false
```

**Ver os arquivos que estão no repositório**
```bash
ls devops/exerciophp/
```

**Copiar o arquivo da aplicação para a pasta pública do Apache**
```bash
sudo cp devops/exerciophp/index.php /var/www/html/
```

**Ajustar dono e permissões**
```bash
sudo chown -R apache:apache /var/www/html
sudo chmod -R 755 /var/www/html
```
O usuário do Apache é dono dos arquivos e tem permissão sobre eles.

**Ajustar o SELinux (segurança de controle de acesso)**
```bash
sudo restorecon -Rv /var/www/html
```

**Verificar o resultado**
```bash
hostname -I
```
Mostra o IP da VM, para abrir no navegador.

**Abrir no navegador**
```
http://IP_DA_VM/index.php
```

---

## Script (deploy.sh)

Automatiza a instalação, a cópia dos arquivos e o reinício do serviço.

**Verificar IP**
```bash
ip a
```

**Verificar versão e distribuição**
```bash
cat /etc/os-release
```

**Instalar git**
```bash
sudo dnf install git -y
```

**Clonar o repositório**
```bash
git clone https://github.com/alicevnava/devops.git
```

**Entrar na pasta**
```bash
cd devops/exerciophp
```

**Mostrar os arquivos da pasta**
```bash
ls
```

**Permitir executar o script**
```bash
chmod +x deploy.sh
```

**Executar o script**
```bash
sudo ./deploy.sh
```

**Mostrar o IP**
```bash
hostname -I
```

**Acessar no navegador**
```
http://IP_DA_VM/index.php
```

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
