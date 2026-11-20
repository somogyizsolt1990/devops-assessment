output "namespace" {
  description = "Namespace of the release."
  value       = helm_release.homework.namespace
}

output "release_name" {
  description = "Helm release name."
  value       = helm_release.homework.name
}

output "release_status" {
  description = "Helm release status (deployed, failed, ...)."
  value       = helm_release.homework.status
}

output "release_revision" {
  description = "Helm release revision; increases with every upgrade."
  value       = helm_release.homework.metadata.revision
}

output "image_tag" {
  # Read from the release, not from var.image_tag: after a failed, rolled-back
  # apply the variable would report a tag that is not running.
  description = "Container image tag of the deployed release."
  value       = jsondecode(helm_release.homework.metadata.values).image.tag
}
