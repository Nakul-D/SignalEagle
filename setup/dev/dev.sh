#!/usr/bin/env bash
set -euo pipefail

load_env() {
    if [ ! -f ".env" ]; then
        echo ".env not found. Please run setup first."
        return 1
    fi

    # Export all variables from .env
    set -o allexport
    source .env
    set +o allexport
}

update_env() {
    local key=$1
    local value=${2-} #allows empty values

    if [ -z "${key:-}" ]; then
        echo "Usage: update_env <KEY> <VALUE>"
        return 1
    fi

    if [ ! -f ".env" ]; then
        echo ".env not found."
        return 1
    fi

    # Remove old entry (if exists)
    grep -vE "^${key}=" .env > .env.tmp && mv .env.tmp .env

    # Append new value
    echo "${key}=${value}" >> .env
}

setup() {
    echo "Initializing environment..."

    if [ -f ".env" ]; then
        echo "Setup has already been run (.env exists)."
        echo "If you want to re-run setup, manually delete .env and the IAM role/policy first."
        return 1
    fi

    if ! command -v aws &> /dev/null; then
        echo "AWS CLI is not installed."
        echo "Please install and configure it"
        return 1
    fi

    echo "Creating new .env file..."
    touch .env

    AWS_ACCESS_KEY_ID=""
    AWS_SECRET_ACCESS_KEY=""
    REGION=""

    PROFILES=($(aws configure list-profiles))
    if [ ${#PROFILES[@]} -eq 1 ] && [ "${PROFILES[0]}" = "default" ]; then
        echo "Using default AWS profile."
        AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
        AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
        REGION=$(aws configure get region)
    else
        echo "Multiple or no valid AWS profiles found."
        echo "Please enter your AWS credentials manually."
        read -p "Enter AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
        read -p "Enter AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
        read -p "Enter REGION: " REGION
        echo ""
    fi

    echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> .env
    echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> .env
    echo "REGION=$REGION" >> .env

    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    echo "ACCOUNT_ID=$ACCOUNT_ID" >> .env

    AZ=$(aws ec2 describe-availability-zones --query "AvailabilityZones[0].ZoneName" --output text --region $REGION)
    echo "AZ=$AZ" >> .env

    DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=isDefault,Values=true" \
        --query "Vpcs[0].VpcId" \
        --output text \
        --region $REGION)
    echo "VPC_ID=$DEFAULT_VPC_ID" >> .env

    DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
        --query "join(',', Subnets[].SubnetId)" \
        --output text \
        --region $REGION)
    echo SUBNET_IDS=$DEFAULT_SUBNET_IDS >> .env

    CF_ROLE_NAME=SignalEagle-CF-Dev-Role
    CF_POLICY_NAME=SignalEagle-CF-Dev-Policy
    CF_PERMISSIONS_POLICY_FILE=policies/CF-permission-policy.json
    CF_TRUST_POLICY_FILE=policies/CF-trust-policy.json

    aws iam create-policy \
		--policy-name $CF_POLICY_NAME \
		--policy-document file://$CF_PERMISSIONS_POLICY_FILE \
		--description "CloudFormation execution policy" \
		--no-cli-pager

    CF_POLICY_ARN=arn:aws:iam::$ACCOUNT_ID:policy/$CF_POLICY_NAME

	aws iam create-role \
        --role-name $CF_ROLE_NAME \
        --assume-role-policy-document file://$CF_TRUST_POLICY_FILE \
        --description "Execution role for CloudFormation" \
        --no-cli-pager

    aws iam attach-role-policy \
		--role-name $CF_ROLE_NAME \
		--policy-arn $CF_POLICY_ARN \
		--no-cli-pager

	CF_ROLE_ARN=arn:aws:iam::$ACCOUNT_ID:role/$CF_ROLE_NAME
    echo "CF_ROLE_ARN=$CF_ROLE_ARN" >> .env

    echo "STACK_NAME=signaleagle-dev-stack" >> .env
    TIMESTAMP=$(date +%s)
    echo "DEV_BUCKET_NAME=signaleagle-dev-$TIMESTAMP" >> .env
    echo "TEST_BUCKET_NAME=signaleagle-test-$TIMESTAMP" >> .env
    echo "DB_INSTANCE_IDENTIFIER=signaleagle-dev-instance" >> .env
	echo "DB_USERNAME=postgres" >> .env
	echo "DB_PASSWORD=signaleagle-postgres-123" >> .env
    echo "DEV_DB_NAME=signaleagle_dev_db" >> .env
    echo "TEST_DB_NAME=signaleagle_test_db" >> .env

    echo "Setup complete! Environment variables written to .env"
}

up() {
    echo "Deploying AWS resources..."

    load_env

    aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file CF-dev.yml \
        --role-arn "$CF_ROLE_ARN" \
        --region "$REGION" \
        --parameter-overrides \
            AvailabilityZone="$AZ" \
            Vpc="$VPC_ID" \
            Subnets="$SUBNET_IDS" \
            DbInstanceIdentifier="$DB_INSTANCE_IDENTIFIER" \
            DevDbName="$DEV_DB_NAME" \
            DbUsername="$DB_USERNAME" \
            DbPassword="$DB_PASSWORD" \
            DevBucketName="$DEV_BUCKET_NAME" \
            TestBucketName="$TEST_BUCKET_NAME" \
        --no-cli-pager

    RDS_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[0].Outputs[?OutputKey=='RdsInstanceEndpoint'].OutputValue" \
        --output text \
        --region "$REGION")

    RDS_PORT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[0].Outputs[?OutputKey=='RdsInstancePort'].OutputValue" \
        --output text \
        --region "$REGION")

    update_env RDS_ENDPOINT "$RDS_ENDPOINT"
    update_env RDS_PORT "$RDS_PORT"
    update_env DB_SSL_MODE "require"

    echo "AWS resources deployed!"
}

start() {
    echo "Starting docker container..."
    echo "Done!"
}

stop() {
    echo "Stopping docker container..."
    echo "Done!"
}

run_tests() {
    echo "Running tests..."
    echo "Done!"
}

down() {
    echo "Removing deployed AWS resources..."

    load_env

    aws s3 rm s3://$DEV_BUCKET_NAME --recursive --region "$REGION" || true
    aws s3 rm s3://$TEST_BUCKET_NAME --recursive --region "$REGION" || true

    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --role-arn "$CF_ROLE_ARN" \
        --no-cli-pager

    echo "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"

    update_env RDS_ENDPOINT ""
    update_env RDS_PORT ""
    update_env DB_SSL_MODE ""

    echo "Removed deployed AWS resources."
}

echo "=========================================================="
echo "1) Setup - Initialize environment"
echo "2) Up    - Deploy AWS resources"
echo "3) Start - Starts docker containers for development"
echo "4) Stop  - Stops docker containers used for development"
echo "5) Test  - Run tests on Go Fiber app"
echo "6) Down  - Remove deployed AWS resources"
echo "=========================================================="
read -p "Enter your choice [1-6]: " choice
echo "=========================================================="

case $choice in
    1) setup ;;
    2) up ;;
    3) start ;;
    4) stop ;;
    5) run_tests ;;
    6) down ;;
    *) echo "Invalid option. Please choose a number between 1 and 6";;
esac
