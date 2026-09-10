#!/bin/bash

# Atualiza os pacotes do sistema
dnf update -y

# Instala o Apache (httpd), o PHP e o Git
dnf install -y httpd php git

# Habilita e inicia o Apache
systemctl enable --now httpd
# Inicia o Apache
systemctl start httpd

# Clona o repositório com a aplicação
git clone https://github.com/thiagoinacioalves/treinamento.git /tmp/devops

# Copia o arquivo da aplicação para a pasta pública do Apache
cp /tmp/devops/Linux/app-php/index.php /var/www/html/
# Reinicia o Apache
systemctl restart httpd
