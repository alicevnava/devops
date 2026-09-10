#!/bin/bash

# Atualiza os pacotes do sistema
dnf update -y

# Instala o Apache (httpd), o PHP e o Git
dnf install -y httpd php git

# Habilita e inicia o Apache
systemctl enable --now httpd
systemctl start httpd

# Clona o repositório com a aplicação
git clone https://github.com/thiagoinacioalves/treinamento.git /tmp/devops

# Copia o arquivo da aplicação para a pasta pública do Apache
cp /tmp/devops/treinamento/Linux/app-php/index.php /var/www/html/
systemctl restart httpd
