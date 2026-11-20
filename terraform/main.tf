resource "kubernetes_namespace_v1" "homework" {
  metadata {
    name = var.namespace

    labels = {
      # Rejects pods that do not meet the "restricted" Pod Security Standard.
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

resource "helm_release" "homework" {
  name      = "homework"
  chart     = "${path.module}/../helm/myapp"
  namespace = kubernetes_namespace_v1.homework.metadata[0].name

  # A failed release is rolled back and apply fails, so CI sees the error.
  atomic          = true
  cleanup_on_fail = true
  timeout         = 180

  # yamlencode keeps value types: a tag like "1.10" stays a string (set would parse it as a number).
  values = [yamlencode({
    image = {
      tag = var.image_tag
    }
    environment = var.environment
  })]
}
