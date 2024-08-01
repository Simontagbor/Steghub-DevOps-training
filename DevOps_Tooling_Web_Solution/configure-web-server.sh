#!/bin/bash

# Set default values
default_web_server_prefix="Web-Server"
default_nfs_server_name="NFS-Server"

# Check for command line arguments
if [ "$#" -ge 1 ]; then
    web_server_prefix="${1:-$default_web_server_prefix}"
    nfs_server_name="${2:-$default_nfs_server_name}"
    script_path="$3"
    key_path="$4"
else
    # Interactive mode
    read -p "Enter the prefix for the web server instances [$default_web_server_prefix]: " web_server_prefix
    web_server_prefix="${web_server_prefix:-$default_web_server_prefix}"

    read -p "Enter the name of the NFS server instance [$default_nfs_server_name]: " nfs_server_name
    nfs_server_name="${nfs_server_name:-$default_nfs_server_name}"

    read -p "Enter the path to the script to run on the web servers: " script_path
    script_path="${script_path}"

    read -p "Enter the path to the key pair file: " key_path
    key_path="${key_path}"
fi

# Get the private IP address of the NFS server
echo "Fetching private IP address for $nfs_server_name..."

nfs_server_private_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$nfs_server_name" \
    --query "Reservations[].Instances[0].PrivateIpAddress" \
    --output text)

if [ -z "$nfs_server_private_ip" ]; then

    echo "NFS server not found. Please check the name or verify that the server is created."
    exit 1
fi

# Loop through the web servers and configure them
for i in {1..3}; do
    web_server_name="${web_server_prefix}-${i}"
    echo "Configuring web server $web_server_name..."

    # Get the private IP address of the web server
    web_server_public_ip=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$web_server_name" \
        --query "Reservations[].Instances[0].PublicIpAddress" \
        --output text)

    if [ -z "$web_server_public_ip" ]; then
        echo "Web server $web_server_name not found. Please check the name or verify that the server is created."
        continue
    fi

    # Copy the script to the web server
    echo "Copying script to web server $web_server_name..."
    scp -i "$key_path" "$script_path" "ec2-user@$web_server_public_ip:/tmp/"

    # Run the script on the web server
    echo "Running script on web server $web_server_name..."
    ssh -i "$key_path" "ec2-user@$web_server_public_ip" "bash /tmp/$script_path $nfs_server_private_ip"
done

echo "Web servers configured successfully."