#!/bin/bash
sudo su
# To runs this script on the NFS server instance
# Transfer this script to the NFS server instance:
# scp -i "your-key.pem" prepare-NFS-server.sh ec2-user@<NFS-server-public-ip>:/tmp

# run the script on the NFS server instance
# ssh -i "your-key.pem" ec2-user@<NFS-server-public-ip> "bash /tmp/prepare-NFS-server.sh"

# Install neccessary packages
sudo yum update -y
sudo yum install -y lvm2 xfsprogs nfs-utils

# Create a directory to store the NFS data
sudo mkdir -p /mnt/nfs


# Create Physical Volumes
sudo pvcreate /dev/xvdf /dev/xvdg /dev/xvdh # add the EBS device names here

# Create a Volume Group named VG_NFS
sudo vgcreate VG_NFS /dev/xvdf /dev/xvdg /dev/xvdh # add the EBS device names here

# Create Logical Volumes
lvcreate -L 10G -n lv-opt VG_NFS
lvcreate -L 10G -n lv-apps VG_NFS
lvcreate -L 5G -n lv-logs VG_NFS

# Format Logical Volumes with XFS
sudo mkfs.xfs /dev/VG_NFS/lv-opt
sudo mkfs.xfs /dev/VG_NFS/lv-apps
sudo mkfs.xfs /dev/VG_NFS/lv-logs

# Create mount points in the /mnt directory
sudo mkdir -p /mnt/opt
sudo mkdir -p /mnt/apps
sudo mkdir -p /mnt/logs

# Mount the Logical Volumes
sudo mount /dev/VG_NFS/lv-opt /mnt/opt
sudo mount /dev/VG_NFS/lv-apps /mnt/apps
sudo mount /dev/VG_NFS/lv-logs /mnt/logs

# add entries to /etc/fstab for automatic mounting on boot
echo "/dev/VG_NFS/lv-opt /mnt/opt xfs defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/dev/VG_NFS/lv-apps /mnt/apps xfs defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/dev/VG_NFS/lv-logs /mnt/logs xfs defaults 0 0" | sudo tee -a /etc/fstab > /dev/null

# Start and enable NFS services
sudo systemctl start nfs-server.service
sudo systemctl enable nfs-server.service

