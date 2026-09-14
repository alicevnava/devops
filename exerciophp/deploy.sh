#!/bin/bash

# Atualiza os pacotes do sistema
dnf update -y

# Instala o Apache (httpd), o PHP e o Git
dnf install -y httpd php git

# Habilita e inicia o Apache
systemctl enable --now httpd

# Clona o repositório com a aplicação
git clone https://github.com/alicevnava/devops.git /tmp/devops

# Copia o arquivo da aplicação para a pasta pública do Apache
cp /tmp/devops/exerciophp/index.php /var/www/html/

# Reinicia o Apache
systemctl restart httpd

# Mostra o endereço para acessar no navegador
echo "Acesse no navegador: http://$(hostname -I)/index.php"
