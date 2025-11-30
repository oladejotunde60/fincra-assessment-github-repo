# Destroy Workflow Guide

This guide explains how to use the automated destroy workflow to tear down your EKS infrastructure from GitHub Actions.

---

## 🎯 Purpose

The destroy workflow (`destroy.yml`) provides a safe, controlled way to delete all AWS resources from your CI/CD pipeline without needing local access.

---

## 🚀 How to Use

### Step 1: Navigate to GitHub Actions

1. Go to your GitHub repository
2. Click on the **"Actions"** tab
3. Select **"Destroy Flask EKS Infrastructure"** from the workflows list (left sidebar)

### Step 2: Trigger the Workflow

1. Click the **"Run workflow"** button (top right)
2. You'll see a form with two inputs:

   **Input 1: Confirmation**
   - Type exactly: `destroy` (lowercase)
   - This is a safety measure to prevent accidental deletions

   **Input 2: Delete ECR Images**
   - ✅ Checked (default) - Deletes all Docker images from ECR before destroying
   - ☐ Unchecked - Keeps Docker images, only destroys ECR repository

3. Click **"Run workflow"** to start

### Step 3: Monitor Progress

The workflow runs in 4 parallel/sequential jobs:

```
1. validate-destroy       → Confirms you typed "destroy" correctly
2. cleanup-kubernetes     → Deletes K8s resources (deployments, services, etc.)
3. cleanup-ecr (optional) → Deletes Docker images from ECR
4. terraform-destroy      → Destroys all infrastructure (EKS, VPC, IAM, etc.)
5. summary                → Shows final status report
```

---

## 📋 What Gets Deleted

### Kubernetes Resources
- Flask app namespace and all resources
- AWS Load Balancer Controller
- All pods, services, ingresses, deployments

### AWS Infrastructure
- ✅ EKS Cluster (`fincra-test-eks-cluster`)
- ✅ ECR Repository (`flask-app`)
- ✅ All Docker images in ECR (if selected)
- ✅ VPC, Subnets, Route Tables
- ✅ Internet Gateway, NAT Gateways
- ✅ Security Groups
- ✅ IAM Roles and Policies
- ✅ Fargate Profiles
- ✅ Load Balancers (ALB/NLB)

---

## ⏱️ Expected Duration

| Phase | Duration |
|-------|----------|
| Validation | ~5 seconds |
| Kubernetes Cleanup | ~2-5 minutes |
| ECR Cleanup | ~30 seconds |
| Terraform Destroy | ~10-15 minutes |
| **Total** | **~15-20 minutes** |

The EKS cluster deletion is the longest step.

---

## 🔒 Safety Features

1. **Manual Trigger Only** - Cannot be triggered automatically
2. **Confirmation Required** - Must type "destroy" exactly
3. **Validation Step** - Workflow fails if confirmation is wrong
4. **Continue-on-Error** - Won't stop if some resources don't exist
5. **Import Before Destroy** - Imports resources into state if needed
6. **Detailed Summary** - Shows what was deleted at the end

---

## 🚨 Important Notes

### Before Running Destroy

⚠️ **This action is irreversible!**

- All data in the cluster will be lost
- All Docker images will be deleted (if selected)
- You cannot undo this operation
- Make sure you have backups if needed

### After Destroy Completes

✅ Your next deployment will:
- Create fresh infrastructure
- Not need import steps (everything is clean)
- Take ~15-20 minutes to complete

---

## 🐛 Troubleshooting

### "Workflow failed at validation"
**Problem:** You didn't type "destroy" exactly
**Solution:** Run again and type `destroy` (lowercase, no spaces)

### "Some resources still exist after destroy"
**Problem:** Resources may be stuck in "deleting" state
**Solution:** 
1. Wait 5-10 minutes and check AWS console
2. Manually delete stuck resources if needed
3. Common: LoadBalancers take time to delete

### "Cannot import resource"
**Problem:** Resource doesn't exist or already in state
**Solution:** This is normal - the workflow continues anyway

### "Terraform destroy failed"
**Problem:** Dependencies preventing deletion
**Solution:**
1. Check logs for specific resource blocking deletion
2. Manually delete that resource in AWS console
3. Re-run the destroy workflow

---

## 📊 Workflow Summary

After completion, GitHub Actions will show a summary with:

- ✅ Status of each job (success/failure)
- 📋 List of resources destroyed
- ⏰ Timestamp and who triggered it
- 💡 Next steps and recommendations

---

## 🔄 Alternative: Local Destroy

If you prefer to destroy locally instead:

```bash
cd /Users/fmy-555/Documents/aws-eks/fincra-assessment-github-repo/terraform

# Import existing resources first
terraform import aws_ecr_repository.flask_app flask-app
terraform import aws_eks_cluster.main fincra-test-eks-cluster
# ... (other imports)

# Then destroy
terraform destroy -auto-approve
```

**Note:** This requires:
- AWS credentials configured locally
- Terraform state populated (via imports)
- Takes the same ~15-20 minutes

---

## 📝 Best Practices

1. **Run during off-hours** - Avoid impacting others
2. **Notify team members** - Let them know you're destroying infrastructure
3. **Double-check confirmation** - Make sure you're destroying the right cluster
4. **Review logs** - Check the workflow logs for any issues
5. **Verify in AWS Console** - Confirm resources are actually deleted

---

## 🎓 Example Scenarios

### Scenario 1: Clean Slate for Re-deployment
```
1. Run destroy workflow
2. Wait for completion (~15 minutes)
3. Push code changes to trigger deploy workflow
4. New infrastructure created from scratch
```

### Scenario 2: Cost Savings
```
1. Run destroy workflow at end of day
2. Resources deleted (no charges overnight)
3. Re-deploy next morning when needed
```

### Scenario 3: Fixing Broken State
```
1. Run destroy workflow to clear everything
2. Remove import steps from config.yml (optional)
3. Push changes to deploy fresh
4. Everything starts clean
```

---

## 📞 Support

If you encounter issues:
1. Check the workflow logs in GitHub Actions
2. Review AWS CloudFormation events for stuck stacks
3. Check AWS Console for resources in "deleting" state
4. Refer to TROUBLESHOOTING_FLOWCHART.md for common issues

---

**Last Updated:** November 30, 2025  
**Workflow Version:** 1.0  
**Terraform Version:** 1.5.7
