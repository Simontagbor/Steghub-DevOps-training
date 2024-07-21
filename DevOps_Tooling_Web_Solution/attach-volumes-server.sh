#!/bin/bash

# specify default values
default_prefix="Default-Volume"

# Function to attach volume
attach_volume() {
    local volume_id=$1
    local instance_id=$2
    local device_name=$3

    aws ec2 attach-volume --volume-id "$volume_id" \
        --instance-id "$instance_id" \
        --device "$device_name"
}

# Function to display a spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep -e $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
# Check for command line arguments
if [ "$#" -ge 1 ]; then
    instance_name="${1:-$instance_name}"
    volume_name_prefix="${2:-$default_prefix}"
else
    # Prompt the user for the instance name
    read -p "Enter the name of the NFS server instance: " instance_name

    # prompt the user for prefix of the volumes name
    read -p "Enter volume name prefix for each volume [$default_prefix]: " volume_name_prefix
    volume_name_prefix="${volume_name_prefix:-$default_prefix}"
fi

echo "Fetching instance ID for $instance_name..."
# Retrieve the instance ID based on the instance name

instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$instance_name" \
    --query "Reservations[].Instances[?State.Name=='running'].InstanceId" \
    --output text)

# Check if the instance ID was found
if [ -z "$instance_id" ]; then
    echo "Instance not found. Please check the name or verify that the server is created."
    exit 1
fi

# Ask the user to specify the operating system
echo "Please specify the operating system of the NFS server instance:"
select os_type in RedHat Ubuntu AWS; do
    case $os_type in
        RedHat ) device_names=("/dev/sdf" "/dev/sdg" "/dev/sdh"); break;;
        Ubuntu ) device_names=("/dev/xvdf" "/dev/xvdg" "/dev/xvdh"); break;;
        AWS ) device_names=("/dev/nvme1n1" "/dev/nvme2n1" "/dev/nvme3n1"); break;;
        * ) echo "Invalid selection. Please try again."; continue;;
    esac
done



# Loop through the volume names and attach them
for i in {1..3}; do
    volume_name="${volume_name_prefix}-${i}"
    volume_id=$(aws ec2 describe-volumes \
        --filters "Name=tag:Name,Values=$volume_name" \
        --query "Volumes[].VolumeId" \
        --output text)
    
    if [ -z "$volume_id" ]; then
        echo "Volume $volume_name not found."
        echo "please create $volume_name volume using create-ebs-volumes.sh script"
        echo "Exiting..."
        exit 1
    fi
    echo "Attaching volume $volume_name to instance $instance_name..."  
    (attach_volume "$volume_id" "$instance_id" "${device_names[$((i-1))]}") & spinner
done

echo "Volumes attached successfully."
