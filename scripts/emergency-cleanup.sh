#!/bin/bash
set -e

# Emergency Cleanup Script
# Use this if the destroy workflow fails or you need immediate cleanup

echo "🧹 Starting emergency cleanup of AWS resources..."
echo ""

REGION="eu-west-1"
CLUSTER_NAME="fincra-test-eks-cluster"
ECR_REPO="flask-app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}⚠️  WARNING: This will delete AWS resources!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1: Cleaning up EKS Cluster${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if cluster exists
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "Found EKS cluster: $CLUSTER_NAME"
    
    # Delete Fargate profiles
    echo "Deleting Fargate profiles..."
    FARGATE_PROFILES=$(aws eks list-fargate-profiles \
        --cluster-name "$CLUSTER_NAME" \
        --region "$REGION" \
        --query 'fargateProfileNames[*]' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$FARGATE_PROFILES" ]; then
        for profile in $FARGATE_PROFILES; do
            echo "  Deleting Fargate profile: $profile"
            aws eks delete-fargate-profile \
                --cluster-name "$CLUSTER_NAME" \
                --fargate-profile-name "$profile" \
                --region "$REGION" 2>/dev/null || echo "  Failed or already deleting"
        done
        echo "  Waiting for Fargate profiles to delete (60s)..."
        sleep 60
    else
        echo "  No Fargate profiles found"
    fi
    
    # Delete node groups
    echo "Deleting node groups..."
    NODE_GROUPS=$(aws eks list-nodegroups \
        --cluster-name "$CLUSTER_NAME" \
        --region "$REGION" \
        --query 'nodegroups[*]' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$NODE_GROUPS" ]; then
        for ng in $NODE_GROUPS; do
            echo "  Deleting node group: $ng"
            aws eks delete-nodegroup \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$ng" \
                --region "$REGION" 2>/dev/null || echo "  Failed or already deleting"
        done
        echo "  Waiting for node groups to delete (60s)..."
        sleep 60
    else
        echo "  No node groups found"
    fi
    
    # Delete cluster
    echo "Deleting EKS cluster..."
    aws eks delete-cluster \
        --name "$CLUSTER_NAME" \
        --region "$REGION" 2>/dev/null || echo "  Failed or already deleting"
    echo -e "${GREEN}✅ EKS cluster deletion initiated${NC}"
else
    echo "No EKS cluster found"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2: Cleaning up VPCs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Find all VPCs with the cluster name
VPC_IDS=$(aws ec2 describe-vpcs \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=*$CLUSTER_NAME*" \
    --query 'Vpcs[*].VpcId' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$VPC_IDS" ]; then
    echo "Found VPCs to delete: $VPC_IDS"
    
    for vpc_id in $VPC_IDS; do
        echo ""
        echo "Processing VPC: $vpc_id"
        
        # Delete NAT Gateways
        echo "  Deleting NAT Gateways..."
        NAT_GWS=$(aws ec2 describe-nat-gateways \
            --region "$REGION" \
            --filter "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available" \
            --query 'NatGateways[*].NatGatewayId' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$NAT_GWS" ]; then
            for nat in $NAT_GWS; do
                echo "    Deleting NAT Gateway: $nat"
                aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region "$REGION" 2>/dev/null || true
            done
            echo "    Waiting for NAT Gateways to delete (60s)..."
            sleep 60
        fi
        
        # Delete Load Balancers (ALB/NLB)
        echo "  Checking for Load Balancers..."
        LBS=$(aws elbv2 describe-load-balancers \
            --region "$REGION" \
            --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$LBS" ]; then
            for lb in $LBS; do
                echo "    Deleting Load Balancer: $lb"
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb" --region "$REGION" 2>/dev/null || true
            done
            echo "    Waiting for Load Balancers to delete (30s)..."
            sleep 30
        fi
        
        # Delete Internet Gateways
        echo "  Deleting Internet Gateways..."
        IGW_IDS=$(aws ec2 describe-internet-gateways \
            --region "$REGION" \
            --filters "Name=attachment.vpc-id,Values=$vpc_id" \
            --query 'InternetGateways[*].InternetGatewayId' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$IGW_IDS" ]; then
            for igw in $IGW_IDS; do
                echo "    Detaching and deleting IGW: $igw"
                aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc_id" --region "$REGION" 2>/dev/null || true
                aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region "$REGION" 2>/dev/null || true
            done
        fi
        
        # Delete Subnets
        echo "  Deleting Subnets..."
        SUBNET_IDS=$(aws ec2 describe-subnets \
            --region "$REGION" \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query 'Subnets[*].SubnetId' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$SUBNET_IDS" ]; then
            for subnet in $SUBNET_IDS; do
                echo "    Deleting subnet: $subnet"
                aws ec2 delete-subnet --subnet-id "$subnet" --region "$REGION" 2>/dev/null || true
            done
        fi
        
        # Delete Route Tables (non-main)
        echo "  Deleting Route Tables..."
        RT_IDS=$(aws ec2 describe-route-tables \
            --region "$REGION" \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query 'RouteTables[?Associations[0].Main != `true`].RouteTableId' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$RT_IDS" ]; then
            for rt in $RT_IDS; do
                echo "    Deleting route table: $rt"
                aws ec2 delete-route-table --route-table-id "$rt" --region "$REGION" 2>/dev/null || true
            done
        fi
        
        # Delete Security Groups (non-default)
        echo "  Deleting Security Groups..."
        SG_IDS=$(aws ec2 describe-security-groups \
            --region "$REGION" \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query 'SecurityGroups[?GroupName != `default`].GroupId' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$SG_IDS" ]; then
            for sg in $SG_IDS; do
                echo "    Deleting security group: $sg"
                aws ec2 delete-security-group --group-id "$sg" --region "$REGION" 2>/dev/null || true
            done
        fi
        
        # Delete VPC
        echo "  Deleting VPC: $vpc_id"
        aws ec2 delete-vpc --vpc-id "$vpc_id" --region "$REGION" 2>/dev/null || echo "  Failed (may have dependencies)"
        
        echo -e "${GREEN}  ✅ VPC $vpc_id cleanup attempted${NC}"
    done
else
    echo "No VPCs found with cluster name"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3: Cleaning up ECR${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleting ECR images..."
    aws ecr batch-delete-image \
        --repository-name "$ECR_REPO" \
        --region "$REGION" \
        --image-ids "$(aws ecr list-images --repository-name "$ECR_REPO" --region "$REGION" --query 'imageIds[*]' --output json)" 2>/dev/null || true
    
    echo "Deleting ECR repository..."
    aws ecr delete-repository \
        --repository-name "$ECR_REPO" \
        --region "$REGION" \
        --force 2>/dev/null || true
    echo -e "${GREEN}✅ ECR cleanup complete${NC}"
else
    echo "No ECR repository found"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4: Cleaning up IAM${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Detach and delete ALB Controller Policy
POLICY_NAME="fincra-test-eks-cluster-AWSLoadBalancerControllerIAMPolicy"
POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" \
    --output text 2>/dev/null || echo "")

if [ ! -z "$POLICY_ARN" ]; then
    echo "Found policy: $POLICY_ARN"
    
    # Detach from all roles
    ATTACHED_ROLES=$(aws iam list-entities-for-policy \
        --policy-arn "$POLICY_ARN" \
        --query 'PolicyRoles[*].RoleName' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$ATTACHED_ROLES" ]; then
        for role in $ATTACHED_ROLES; do
            echo "  Detaching policy from role: $role"
            aws iam detach-role-policy --role-name "$role" --policy-arn "$POLICY_ARN" 2>/dev/null || true
        done
    fi
    
    echo "  Deleting policy..."
    aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null || true
    echo -e "${GREEN}✅ IAM policy cleanup complete${NC}"
else
    echo "No IAM policy found"
fi

# Delete IAM roles
for role in "fincra-test-eks-cluster-cluster-role" "fincra-test-eks-cluster-fargate-pod-execution-role" "fincra-test-eks-cluster-aws-load-balancer-controller"; do
    if aws iam get-role --role-name "$role" >/dev/null 2>&1; then
        echo "Deleting IAM role: $role"
        
        # Detach all managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "$role" \
            --query 'AttachedPolicies[*].PolicyArn' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$ATTACHED_POLICIES" ]; then
            for policy in $ATTACHED_POLICIES; do
                echo "  Detaching policy: $policy"
                aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" 2>/dev/null || true
            done
        fi
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name "$role" \
            --query 'PolicyNames[*]' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$INLINE_POLICIES" ]; then
            for policy in $INLINE_POLICIES; do
                echo "  Deleting inline policy: $policy"
                aws iam delete-role-policy --role-name "$role" --policy-name "$policy" 2>/dev/null || true
            done
        fi
        
        # Delete role
        aws iam delete-role --role-name "$role" 2>/dev/null || true
        echo -e "${GREEN}✅ Role $role deleted${NC}"
    fi
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Cleanup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Note: Some resources may take time to fully delete.${NC}"
echo -e "${YELLOW}Wait 5-10 minutes before redeploying.${NC}"
echo ""
echo "Verify cleanup:"
echo "  aws ec2 describe-vpcs --region eu-west-1 --query 'Vpcs[*].[VpcId,Tags[?Key==\`Name\`].Value|[0]]' --output table"
