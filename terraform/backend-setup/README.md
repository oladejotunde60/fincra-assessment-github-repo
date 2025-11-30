# Terraform Backend Setup Guide

This directory contains Terraform configuration to create the S3 bucket and DynamoDB table needed for remote state management.

---

## 🎯 Purpose

Set up remote backend infrastructure for Terraform state storage:
- **S3 Bucket**: Stores the terraform.tfstate file
- **DynamoDB Table**: Provides state locking to prevent concurrent modifications

---

## 📋 Prerequisites

- AWS credentials configured (same as main project)
- Terraform installed (v1.5.0+)
- AWS CLI configured with appropriate permissions

---

## 🚀 Quick Setup (One-Time)

### Step 1: Create Backend Infrastructure

```bash
# Navigate to backend-setup directory
cd /Users/fmy-555/Documents/aws-eks/fincra-assessment-github-repo/terraform/backend-setup

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create the resources
terraform apply
```

**Expected output:**
```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

backend_configuration = <<EOT
  backend "s3" {
    bucket         = "fincra-terraform-state-837644358342"
    key            = "eks-flask-app/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "fincra-terraform-state-lock"
    encrypt        = true
  }
EOT
dynamodb_table_name = "fincra-terraform-state-lock"
s3_bucket_name = "fincra-terraform-state-837644358342"
```

### Step 2: Copy Backend Configuration

Copy the `backend_configuration` output from Step 1.

### Step 3: Update Main Terraform Configuration

Edit `../versions.tf` and replace the commented backend section:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # ... existing providers ...
  }

  # Paste the backend configuration here
  backend "s3" {
    bucket         = "fincra-terraform-state-837644358342"  # From output
    key            = "eks-flask-app/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "fincra-terraform-state-lock"         # From output
    encrypt        = true
  }
}
```

### Step 4: Reconfigure Main Terraform

```bash
# Navigate back to main terraform directory
cd /Users/fmy-555/Documents/aws-eks/fincra-assessment-github-repo/terraform

# Reinitialize Terraform with new backend
terraform init -reconfigure

# Confirm migration
# If you have local state, Terraform will ask if you want to migrate it to S3
# Type "yes" to migrate
```

### Step 5: Verify Backend Configuration

```bash
# Check that state is now in S3
aws s3 ls s3://fincra-terraform-state-837644358342/eks-flask-app/

# You should see: terraform.tfstate
```

---

## 🔧 What Gets Created

### S3 Bucket
- **Name**: `fincra-terraform-state-<account-id>`
- **Versioning**: Enabled (keeps history of state changes)
- **Encryption**: AES256 encryption at rest
- **Public Access**: Blocked (secure by default)
- **Lifecycle**: Deletes old versions after 90 days
- **Region**: eu-west-1

### DynamoDB Table
- **Name**: `fincra-terraform-state-lock`
- **Billing**: Pay-per-request (no fixed costs)
- **Purpose**: State locking to prevent conflicts
- **Region**: eu-west-1

---

## 💰 Cost Estimate

### Monthly Costs (Approximate)
- **S3 Storage**: ~$0.01 - $0.05/month
  - State files are typically < 1MB
  - First 50TB is $0.023 per GB
- **S3 Requests**: ~$0.01/month
  - Minimal API calls
- **DynamoDB**: ~$0.00 - $0.01/month
  - Pay-per-request pricing
  - Very few operations
- **Total**: **~$0.02 - $0.07/month** (negligible)

---

## 🔄 CI/CD Integration

### Update GitHub Actions Workflow

No changes needed! The backend configuration is in the Terraform files, so CI/CD will automatically use S3 backend after you push the changes.

**What happens in CI/CD:**
1. `terraform init` downloads state from S3
2. `terraform plan/apply` updates state in S3
3. State persists between workflow runs ✅

---

## 🎁 Benefits of Remote State

✅ **Persistent State**: State survives between CI/CD runs  
✅ **State Locking**: Prevents concurrent modifications  
✅ **State History**: S3 versioning keeps old versions  
✅ **Team Collaboration**: Multiple people can use same state  
✅ **Backup**: State is safely stored in S3  
✅ **Encryption**: State is encrypted at rest  
✅ **No Import Needed**: Can deploy without destroying first  

---

## 🧹 Cleanup

### To Remove Backend Infrastructure

```bash
cd /Users/fmy-555/Documents/aws-eks/fincra-assessment-github-repo/terraform/backend-setup

# First, remove backend from main Terraform
# Comment out the backend block in ../versions.tf
cd ..
terraform init -reconfigure -migrate-state

# Then destroy backend resources
cd backend-setup
terraform destroy
```

**⚠️ Warning**: Only do this after migrating state back to local!

---

## 🐛 Troubleshooting

### Error: "Backend configuration changed"
```bash
terraform init -reconfigure
```

### Error: "Failed to get existing workspaces"
```bash
# Check if bucket exists
aws s3 ls | grep terraform-state

# Check if table exists
aws dynamodb list-tables | grep terraform-state-lock
```

### Error: "Access Denied" when accessing S3
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check bucket permissions
aws s3api get-bucket-policy --bucket <bucket-name>
```

### Want to see current state
```bash
# Download state file
aws s3 cp s3://fincra-terraform-state-<account-id>/eks-flask-app/terraform.tfstate ./state-backup.json

# View it
cat state-backup.json | jq
```

---

## 📝 Best Practices

1. **Never commit state files**: Already in .gitignore
2. **Use state locking**: Prevents concurrent modifications
3. **Enable versioning**: Allows state recovery
4. **Encrypt at rest**: Protects sensitive data
5. **Regular backups**: S3 versioning handles this
6. **Limit access**: Use IAM policies for bucket access

---

## 🔐 Security Notes

- State files contain sensitive data (passwords, keys)
- S3 bucket is encrypted at rest
- Public access is blocked by default
- Only authorized IAM users can access
- Consider adding bucket policy for additional restrictions

---

## 📚 Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB State Locking](https://www.terraform.io/docs/language/state/locking.html)

---

**Created:** November 30, 2025  
**Project:** Flask EKS Application  
**Region:** eu-west-1
