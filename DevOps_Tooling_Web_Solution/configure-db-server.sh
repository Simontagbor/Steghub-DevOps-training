# configure-db-server.sh

#!/bin/bash

# Install MySQL
sudo apt-get update
sudo apt-get install -y mysql-server

# Start MySQL service
sudo systemctl start mysql
sudo systemctl enable mysql


# Log into MySQL as the root user
sudo mysql -e "
CREATE DATABASE IF NOT EXISTS tooling;


CREATE USER IF NOT EXISTS 'webaccess'@'172.31.%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON tooling.* TO 'webaccess'@'172.31.%';

FLUSH PRIVILEGES;

CREATE USER 'admin'@'%' IDENTIFIED BY 'admin';
GRANT ALL PRIVILEGES ON tooling.* TO 'admin'@'%';
FLUSH PRIVILEGES;
"
