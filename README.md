# Setup Instructions

## Prerequisites
- AWS CLI configured with appropriate credentials (`aws sso login`)
- kubectl installed
- helm installed
- Terraform installed

## Setup

1. **Fork this repository**
   - Fork the repository on GitHub to your own account
   - Clone your fork locally:
     ```bash
     git clone git@github.com:<your-username>/support-cci-server-setup.git
     cd support-cci-server-setup
     ```

2. **Get secrets zip and unzip to root folder**
   - Download secrets from [1Password](https://start.1password.com/open/i?a=RF46QVWYHJALTBFLBRYFJHHCXU&v=wu3kikbk6yafbtv62qom3ebt5m&i=2cuzpbzqowbhhsn4j7ekp4h2wy&h=circleci.1password.com) and unzip to root folder. Should be support-cci-server-setup/secrets/

3. **Create S3 bucket for Terraform state**
   - Create an S3 bucket in your AWS account (e.g., `ka-cci-terraform-state`)
   - Update the `backend "s3"` block in `terraform/main.tf` with your bucket name

4. **Modify Terraform configuration**
   - Update `terraform/main.tf`:
     - Set `cluster_name` in locals
     - Set `region` if different
     - Update `email` with your email
     - Update `hosted_zones` with your Route53 hosted zone ARN
     - Update `public_subnets`, they must be unique across VPCs (If they conflict during terraform apply, just bump them)
     - **Set `subdomain`** to your desired subdomain:
       - For a subdomain: `"circleci"` for `circleci.yourdomain.com`, or `"mycci"` for `mycci.yourdomain.com`
       - For root domain: Set to `""` (empty string) to deploy to `yourdomain.com`
     - Set `base_domain` to match your Route53 hosted zone domain (e.g., `"ka-cci.com"`)
   - Update `terraform/nomad-client.tf`:
      - Either remove `ssh_key  = file("~/.ssh/id_ed25519.pub")` or set it to your own public key (For ssh access onto nomad clients)
      - Note: `nomad_server_hostname` is now automatically set from `subdomain` and `base_domain` in `main.tf`

5. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

6. **Deploy Infrastructure**
   ```bash
   terraform apply --auto-approve
   ```
   After running this you might get an error that your public subnets overlap. If this is the case, bump the 3rd octet in the ip string so they don't conflict with existing an VPC setup.

7. **Modify Helm values.yaml file**
   - Edit `k8s/applications/values.yaml`:
     - From the terraform apply command in the previous step, take the securityGroupId and subnets, and replace the values in `machine_provisioner.providers.ec2.subnets` and `machine_provisioner.providers.ec2.securityGroupId`.
     - **Update domain configuration** (must match the `subdomain` you set in `terraform/main.tf`):
       - For subdomain: `global.aws.domainName` should be `"<your-subdomain>.<your-base-domain>"` (e.g., `"mycci.ka-cci.com"`)
       - For root domain: `global.aws.domainName` should be `"<your-base-domain>"` (e.g., `"ka-cci.com"`)
       - `nginx.annotations."external-dns.alpha.kubernetes.io/hostname"`: 
         - For subdomain: `"<your-subdomain>.<your-base-domain>, app.<your-subdomain>.<your-base-domain>"` (e.g., `"mycci.ka-cci.com, app.mycci.ka-cci.com"`)
         - For root domain: `"<your-base-domain>, app.<your-base-domain>"` (e.g., `"ka-cci.com, app.ka-cci.com"`)
     - Update the following:
       - `argocd.repository`
       - `global.clusterName`
       - `global.aws.region`
       - `global.aws.domainFilter` (should match `base_domain` from terraform)
       - `machine_provisioner.providers.ec2.region`
       - `machine_provisioner.providers.ec2.tags.owner`
       - `kong.acme.email`
       - `object_storage.bucketName`
       - `object_storage.region`
     - Update `object_storage.bucketName` to match your S3 bucket name. By default it will be `<cluster-name>-cci`

8. **Push updated values to your fork**
   ```bash
   git commit -am "Updated values.yaml" && git push
   ```

9. **Connect to EKS Cluster**
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region <region>
   ```
   Replace `<cluster-name>` and `<region>` with values from your Terraform configuration.

10. **Set Environment Variables**
    Get github client id/secret from:
    https://circleci.com/docs/server-admin/latest/installation/phase-1-aws-prerequisites/#create-a-new-github-oauth-app

    And then run
    ```bash
    export REPO_URL=https://github.com/<your-username>/support-cci-server-setup.git
    export GH_CLIENT_ID=<client-id>
    export GH_CLIENT_SECRET=<client-secret>
    ```

11. **Run Bootstrap Script**
    ```bash
    cd k8s/bootstrap
    ./bootstrap.sh
    ```

12. Wait for `kubectl get pods -n circleci-server | grep kong` to be ready, then navigate to:
    - For subdomain: https://[your-subdomain].[yourdomain] (e.g., https://mycci.ka-cci.com if you set subdomain to "mycci")
    - For root domain: https://[yourdomain] (e.g., https://ka-cci.com if you set subdomain to "")

13. (Optional) If pods are failing you will probably need to run `hacks/run-hacks.sh` because nomad server start up sometimes fails due to them not all starting at the same time.

## Development

After making any changes, push to the repository. ArgoCD will automatically apply them to the cluster (refresh interval: 3 minutes).

To force an immediate refresh:
```bash
kubectl annotate app app-of-apps -n argocd argocd.argoproj.io/refresh=normal --overwrite
```

# Monitoring

Monitoring will be set up after bootstrap. Run `./portforward.sh` to port-forward these services:

You can then navigate to:

- argocd: https://localhost:8080
   - User/Pass is admin/$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
- jaeger: http://localhost:7070
- prometheus: https://localhost:9090
- nomad-server-ui: http://localhost:4646/ui/jobs


## Troubleshooting

Known issues and workarounds:

1. nomad servers need to start up together, if they don't then you need to delete all pods
   See `hacks/nomad-fix.sh`

2. policyService doesn't currently override db with new secret
   See `hacks/policy-service-fix.sh`