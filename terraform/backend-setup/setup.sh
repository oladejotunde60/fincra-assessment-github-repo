#!/bin/bash
set -e

# Terraform Backend Setup Script
# This script creates S3 bucket and DynamoDB table for remote state management

echo "🚀 Starting Terraform Backend Setup..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}Step 1: Initializing Terraform...${NC}"
terraform init

echo ""
echo -e "${BLUE}Step 2: Planning backend infrastructure...${NC}"
terraform plan -out=backend.tfplan

echo ""
echo -e "${YELLOW}Review the plan above. This will create:${NC}"
echo "  - S3 bucket for state storage"
echo "  - DynamoDB table for state locking"
echo ""
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}❌ Setup cancelled.${NC}"
    rm -f backend.tfplan
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Creating backend infrastructure...${NC}"
terraform apply backend.tfplan

echo ""
echo -e "${GREEN}✅ Backend infrastructure created successfully!${NC}"
echo ""

# Get the outputs
S3_BUCKET=$(terraform output -raw s3_bucket_name)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
BACKEND_CONFIG=$(terraform output -raw backend_configuration)

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Backend Infrastructure Created:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}S3 Bucket:${NC} $S3_BUCKET"
echo -e "${BLUE}DynamoDB Table:${NC} $DYNAMODB_TABLE"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Add this backend configuration to ../versions.tf:"
echo ""
echo -e "${YELLOW}$BACKEND_CONFIG${NC}"
echo ""
echo "2. Reinitialize main Terraform:"
echo -e "${BLUE}   cd ..${NC}"
echo -e "${BLUE}   terraform init -reconfigure${NC}"
echo ""
echo "3. Verify state is in S3:"
echo -e "${BLUE}   aws s3 ls s3://$S3_BUCKET/eks-flask-app/${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"

# Save backend config to a file for easy reference
cat > backend-config.txt <<EOF
# Add this to terraform/versions.tf

$BACKEND_CONFIG
EOF

echo ""
echo -e "${BLUE}Backend configuration saved to: backend-config.txt${NC}"
