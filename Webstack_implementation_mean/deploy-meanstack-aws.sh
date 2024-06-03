#!/bin/bash

check_stack_exists() {
    local stack_name=$1
    local stack_status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --query 'Stacks[0].StackStatus' 2>/dev/null)
    if [ -z "$stack_status" ]; then
        return 1  # Stack does not exist
    else
        return 0  # Stack exists
    fi
}

check_stack_status() {
    local stack_name=$1
    local status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --query "Stacks[0].StackStatus" --output text)
    if [ "$status" == "CREATE_COMPLETE" ]; then
        return 0
    elif [[ "$status" == *"FAILED"* ]]; then
        return 1
    else
        return 2
    fi
}

get_public_ip() {
    local instance_name=$1
    local public_ip=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)
    if [ -z "$public_ip" ]; then
        echo "Error: Public IP address not found for instance '$instance_name'."
        return 1
    fi
    echo "$public_ip"
}

animate_loading() {
    local delay=0.1
    local chars="/-\|"
    while :; do
        for (( i=0; i<${#chars}; i++ )); do
            sleep $delay
            echo -en "\r$1 ${chars:$i:1}"
        done
    done
}

main() {
    if [ $# -lt 2 ]; then
        echo "Error: Please provide the path to the CloudFormation template file and the instance name."
        echo "Usage: $0 <template-file> <instance-name>"
        exit 1
    fi

    local template_file=$1
    local instance_name=$2
    local stack_name="$instance_name"

    check_stack_exists "$stack_name"
    if [ $? -eq 0 ]; then
        echo "Stack '$stack_name' already exists. Exiting..."
        exit 1
    fi

    echo "Initializing Stack Creation..."
    animate_loading "Initializing Stack Creation..." &
    local init_loading_pid=$!

    aws cloudformation create-stack --stack-name "$stack_name" --template-body "file://$template_file" --parameters ParameterKey=InstanceName,ParameterValue="$instance_name"
    kill $init_loading_pid
    wait $init_loading_pid 2>/dev/null
    echo -e "\rInitialization completed.                        "

    animate_loading "Waiting for stack creation to complete..." &
    local loading_pid=$!

    while true; do
        check_stack_status "$stack_name"
        case $? in
            0)  echo -e "\rStack creation completed successfully.               "
                break;;
            1)  echo -e "\rStack creation failed.                                "
                exit 1;;
        esac
    done

    kill $loading_pid
    wait $loading_pid 2>/dev/null

    animate_loading "Retrieving public IP address..." &
    local ip_loading_pid=$!

    local public_ip=$(get_public_ip "$instance_name")
    kill $ip_loading_pid
    wait $ip_loading_pid 2>/dev/null
    echo -e "\rPublic IP address retrieved.                             "
                             

    echo "MEAN stack app running on AWS EC2 instance: http://$public_ip:3300"
}

main "$@"
