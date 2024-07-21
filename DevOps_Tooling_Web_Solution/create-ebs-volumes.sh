#!/bin/bash

# Function to display a spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\\'
    while [ "$(ps a | awk '{print $1}' | grep -e $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Get the user's default region
default_region=$(aws configure get region)
if [ -z "$default_region" ]; then
    echo "Default region is not set. Please configure it using 'aws configure'."
    exit 1
fi

# Get the first available zone in the default region
default_zone=$(aws ec2 describe-availability-zones \
                --region "$default_region" \
                --query 'AvailabilityZones[0].ZoneName' \
                --output text)

if [ -z "$default_zone" ]; then
    echo "Could not retrieve the default availability zone."
    exit 1
fi

# Default values
default_prefix="Default-Volume"
default_num_volumes=1
default_volume_type="gp2"
default_volume_size="10" # Size in GiB



# Check for command line arguments
if [ "$#" -ge 1 ]; then
    num_volumes="${1:-$default_num_volumes}"
    availability_zone="${2:-$default_zone}"
    volume_type="${3:-$default_volume_type}"
    volume_size="${4:-$default_volume_size}"
    volume_prefix="${5:-$default_prefix}"
else
    # Interactive mode
    read -p "Please Provide the Number of EBS Volumes [$default_num_volumes]: " num_volumes
    num_volumes="${num_volumes:-$default_num_volumes}"

    read -p "Enter volume name prefix for each volume [$default_prefix]: " volume_prefix
    volume_prefix="${volume_prefix:-$default_prefix}"
    
    read -p "Please Provide the Availability Zone [$default_zone]: " availability_zone
    availability_zone="${availability_zone:-$default_zone}"
    
    read -p "Please Provide The Volume Type [$default_volume_type]: " volume_type
    volume_type="${volume_type:-$default_volume_type}"
    
    read -p "Please Enter the Volume Size in GiB [$default_volume_size]: " volume_size
    volume_size="${volume_size:-$default_volume_size}"
fi

for ((i=1; i<=num_volumes; i++)); do
    # Create EBS volume
    volume_id=$(aws ec2 create-volume --size \
             "$volume_size" --availability-zone \
             "$availability_zone" --volume-type \
             "$volume_type" --query 'VolumeId' --output text)

    echo "Created volume: \
                $volume_id in zone: \
                $availability_zone with type: \
                $volume_type and size: ${volume_size}GiB"

    # Tag the volume with a name
    volume_name="${volume_prefix}-${i}"
    aws ec2 create-tags --resources "$volume_id" --tags Key=Name,Value="$volume_name"
    echo "Tagged volume $volume_id with name $volume_name"

    # Wait for the volume to become available
     # Start spinner and wait for the volume to become available
    (aws ec2 wait volume-available --volume-ids "$volume_id") & spinner
    echo "Volume $volume_id is now available"
done

echo "All volumes created successfully..  :)"