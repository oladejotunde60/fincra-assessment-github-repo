#!/bin/bash
set -e

echo "================================================"
echo "Import Existing AWS Resources into Terraform"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

AWS_REGION="${AWS_REGION:-eu-west-1}"
CLUSTER_NAME="${CLUSTER_NAME:-fincra-test-eks-cluster}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-837644358342}"

echo -e "${YELLOW}This script will import existing AWS resources into Terraform state${NC}"
echo ""
echo "Resources to import:"
echo "  - ECR Repository: flask-app"
echo "  - IAM Role: ${CLUSTER_NAME}-cluster-role"
echo "  - IAM Role: ${CLUSTER_NAME}-fargate-pod-execution-role"
echo "  - IAM Policy: ${CLUSTER_NAME}-AWSLoadBalancerControllerIAMPolicy"
echo ""

cd terraform

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

echo ""
echo "Step 1: Importing ECR Repository..."
echo "================================================"
terraform import aws_ecr_repository.flask_app flask-app 2>/dev/null || echo "Already imported or doesn't exist"

echo ""
echo "Step 2: Importing IAM Cluster Role..."
echo "================================================"
terraform import aws_iam_role.eks_cluster ${CLUSTER_NAME}-cluster-role 2>/dev/null || echo "Already imported or doesn't exist"

echo ""
echo "Step 3: Importing IAM Fargate Execution Role..."
echo "================================================"
terraform import aws_iam_role.fargate_pod_execution ${CLUSTER_NAME}-fargate-pod-execution-role 2>/dev/null || echo "Already imported or doesn't exist"

echo ""
echo "Step 4: Importing IAM Load Balancer Controller Policy..."
echo "================================================"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${CLUSTER_NAME}-AWSLoadBalancerControllerIAMPolicy"
terraform import aws_iam_policy.aws_load_balancer_controller ${POLICY_ARN} 2>/dev/null || echo "Already imported or doesn't exist"

echo ""
echo "Step 5: Verifying Terraform State..."
echo "================================================"
terraform state list | grep -E "(ecr_repository|iam_role|iam_policy)"

cd ..

echo ""
echo "================================================"
echo -e "${GREEN}Import Complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Run: cd terraform && terraform plan"
echo "  2. If plan looks good, run: terraform apply"
echo ""
