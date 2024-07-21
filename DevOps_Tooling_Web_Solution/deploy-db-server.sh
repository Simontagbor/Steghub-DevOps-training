#!/bin/bash

# Function to display a spinner
spinner() {
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
# Set default values
default_instance_name="DB-Server"
default_instance_type="t2.micro"
default_os_type="ubuntu"
default_key_name="your-key-pair-name"

# Check for command line arguments
if [ "$#" -ge 1 ]; then
    instance_name="${1:-$default_instance_name}"
    instance_type="${2:-$default_instance_type}"
    os_type="${3:-$default_os_type}"
    key_name="${4:-$default_key_name}"
    key_path="$5"
    setup_script="${6:-None}"
else
    # Interactive mode
    read -p "Enter the name of the database server instance [$default_instance_name]: " instance_name
    instance_name="${instance_name:-$default_instance_name}"

    read -p "Enter the instance type for the database server [$default_instance_type]: " instance_type
    instance_type="${instance_type:-$default_instance_type}"

    read -p "Enter the operating system type for the database server [$default_os_type]: " os_type
    os_type="${os_type:-$default_os_type}"

    read -p "Enter the key pair name for SSH access to the database server [$default_key_name]: " key_name
    key_name="${key_name:-$default_key_name}"

    read -p "please provide the path to the key pair file [$default_key_name.pem]: " key_path
    key_path="${key_path}"

    read -p "Enter the script to run on the database server to configure the database [None]: " setup_script
    setup_script="${setup_script:-None}"
fi

# Fetch the latest Ubuntu 20.04 AMI ID
echo "Getting AMI ID for the latest Ubuntu 20.04 image..."


ami_id=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId]' \
    --output text) 
# Launch the EC2 instance

echo "Launching EC2 instance..."

instance_id=$(aws ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$instance_type" \
    --key-name "$key_name" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
    --query 'Instances[0].InstanceId' \
    --output text) 

echo "Instance $instance_id is being created..."

# Wait for the instance to be created
(aws ec2 wait instance-running --instance-ids "$instance_id") & spinner $!

# Retrieve the public IP address of the instance
public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance $instance_id has been created with public IP address $public_ip"
echo "Waiting for SSH to become available..."
sleep 60
# Run the setup script on the instance if provided
if [ "$setup_script" != "None" ]; then
    echo "Copying setup script to the instance and running it..."
    sudo scp -i "$key_path" "$setup_script" "ubuntu@$public_ip:/tmp/"
    sudo ssh -i "$key_path" "ubuntu@$public_ip" "bash /tmp/$setup_script"
fi 
