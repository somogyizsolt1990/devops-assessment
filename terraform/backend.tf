# GitLab-managed Terraform state (locking, versioning, access via project permissions).
# Partial configuration: address and credentials come from TF_HTTP_* environment
# variables in CI, or from -backend-config options for local runs (personal access token).
terraform {
  backend "http" {}
}
