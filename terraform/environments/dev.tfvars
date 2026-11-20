# Local k3d cluster: k3d cluster create homework -p "8081:80@loadbalancer"
# image_tag is not set here: it changes with every deployment, pass it with -var.
kube_context = "k3d-homework"
namespace    = "myapp-dev"
environment  = "dev"
