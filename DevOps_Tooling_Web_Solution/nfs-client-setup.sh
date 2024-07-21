#!/bin/bash

# not suitable for production

# Check for command line arguments

if [ "$#" -ge 1 ]; then
    nfs_server_private_ip="${1}"
else
    # Interactive mode
    read -p "Enter the private IP address of the NFS server: " nfs_server_private_ip
fi

# Install NFS client utilities
sudo yum update -y
sudo yum install -y nfs-utils nfs4-acl-tools git mysql



# Mount the NFS share

sudo mkdir /var/www
sudo mount -t nfs -o rw,nosuid "$nfs_server_private_ip":/mnt/apps /var/www

# Verify that the NFS share is mounted correctly

sudo df -h

# Persist the changes even after reboot

echo "$nfs_server_private_ip:/mnt/apps /var/www nfs rw,nosuid 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "$nfs_server_private_ip:/mnt/logs /var/log/httpd nfs rw,nosuid 0 0" | sudo tee -a /etc/fstab > /dev/null

# install Remi's Repository, Apache, and PHP
echo "Installing Apache and its dependencies.."
sudo yum install -y httpd


rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
# install php
echo "Installing php and Remi...."
sudo dnf module reset php
sudo dnf module enable php:remi-7.4 -y
sudo dnf install php php-opcache php-gd php-curl php-mysqlnd

# Start php-fpm services
echo "Starting PHP ....."
sudo systemctl start php-fpm
sudo systemctl enable php-fpm

# Start Apache service
sudo chown -R apache:apache /etc/httpd/logs
sudo chmod -R 750 /etc/httpd/logs
# Set SELinux context for Apache web root securely
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html(/.*)?"
sudo restorecon -Rv /var/www/html

sudo getenforce
sudo setenforce 0 # Permissive mode(for testing purposes only)

sudo systemctl start httpd
sudo systemctl enable httpd

sudo setsebool -P httpd_use_nfs 1


