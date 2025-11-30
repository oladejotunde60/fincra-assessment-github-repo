#!/bin/bash

# Verify Cleanup Script
# Run this after emergency-cleanup.sh to confirm everything is deleted

echo "🔍 Verifying AWS Resource Cleanup..."
echo ""

REGION="eu-west-1"
CLUSTER_NAME="fincra-test-eks-cluster"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking Resources..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check EKS Cluster
echo -n "EKS Cluster: "
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}Still exists (may be deleting)${NC}"
else
    echo -e "${GREEN}✅ Deleted${NC}"
fi

# Check ECR Repository
echo -n "ECR Repository: "
if aws ecr describe-repositories --repository-names flask-app --region "$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}Still exists${NC}"
else
    echo -e "${GREEN}✅ Deleted${NC}"
fi

# Check VPCs
echo -n "Project VPCs: "
VPC_COUNT=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Name,Values=*$CLUSTER_NAME*" \
    --query 'Vpcs[*].VpcId' \
    --output text 2>/dev/null | wc -w | tr -d ' ')

if [ "$VPC_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✅ All deleted${NC}"
else
    echo -e "${YELLOW}$VPC_COUNT still exist${NC}"
    aws ec2 describe-vpcs --region "$REGION" \
        --filters "Name=tag:Name,Values=*$CLUSTER_NAME*" \
        --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
        --output table
fi

# Check IAM Roles
echo -n "IAM Roles: "
ROLE_COUNT=$(aws iam list-roles \
    --query "Roles[?contains(RoleName, 'fincra-test')].RoleName" \
    --output text 2>/dev/null | wc -w | tr -d ' ')

if [ "$ROLE_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✅ All deleted${NC}"
else
    echo -e "${YELLOW}$ROLE_COUNT still exist${NC}"
    aws iam list-roles \
        --query "Roles[?contains(RoleName, 'fincra-test')].RoleName" \
        --output table
fi

# Check IAM Policies
echo -n "IAM Policies: "
POLICY_COUNT=$(aws iam list-policies \
    --query "Policies[?contains(PolicyName, 'fincra-test')].PolicyName" \
    --output text 2>/dev/null | wc -w | tr -d ' ')

if [ "$POLICY_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✅ All deleted${NC}"
else
    echo -e "${YELLOW}$POLICY_COUNT still exist${NC}"
    aws iam list-policies \
        --query "Policies[?contains(PolicyName, 'fincra-test')].{Name:PolicyName,Arn:Arn}" \
        --output table
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL_REMAINING=$((VPC_COUNT + ROLE_COUNT + POLICY_COUNT))

if [ "$TOTAL_REMAINING" -eq "0" ]; then
    echo -e "${GREEN}🎉 All resources cleaned up successfully!${NC}"
    echo ""
    echo "You can now safely redeploy."
else
    echo -e "${YELLOW}⚠️  $TOTAL_REMAINING resource(s) still exist${NC}"
    echo ""
    echo "Some resources may still be deleting. Wait a few minutes and run this script again."
    echo ""
    echo "If resources persist after 10 minutes, you may need to manually delete them:"
    echo "  - Go to AWS Console"
    echo "  - Check CloudFormation stacks"
    echo "  - Check VPC dependencies (ENIs, NAT gateways, etc.)"
fi

echo ""
