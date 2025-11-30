# Quick Start: Remote State Setup

## Option 1: Automated Setup (Recommended)

```bash
cd terraform/backend-setup
./setup.sh
```

Follow the prompts, then:

1. Copy the backend configuration shown
2. Paste it into `../versions.tf` (replace the commented section)
3. Run:
   ```bash
   cd ..
   terraform init -reconfigure
   ```

---

## Option 2: Manual Setup

```bash
cd terraform/backend-setup

# Create resources
terraform init
terraform apply

# Get the configuration
terraform output backend_configuration

# Copy output and paste into ../versions.tf
# Then:
cd ..
terraform init -reconfigure
```

---

## Verify It's Working

```bash
# Check state is in S3
aws s3 ls s3://fincra-terraform-state-<account-id>/eks-flask-app/

# Should show: terraform.tfstate
```

---

## Rollback (If Needed)

```bash
cd terraform

# Remove backend from versions.tf (comment it out)
terraform init -reconfigure -migrate-state

# Then destroy backend resources
cd backend-setup
terraform destroy
```

---

## Cost

~$0.02 - $0.07/month (negligible)

---

## Benefits

✅ State persists between CI/CD runs  
✅ No more "already exists" errors  
✅ Can run terraform plan without apply  
✅ State locking prevents conflicts  
✅ Automatic backups with versioning
