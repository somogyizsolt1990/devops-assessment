# Code Review

Thanks for putting the skeleton together – the structure is right: there is a chart, Terraform code and a pipeline, so what is left is making the pieces actually work together. Below are the five things I would fix first, in this order: 1–3 block a working deployment, 4 is a safety risk, and 5 stops these problems from coming back.

Line numbers refer to your original version.

## 1. Terraform does not run at all

- `terraform/main.tf:14` – `value =` is empty: a syntax error.
- `terraform/main.tf:19` – `prod` without quotes is read as a reference to something called `prod`, so it is an "Invalid reference". Strings need quotes – or better, use `var.environment`, which you already declared.
- `terraform/main.tf:9` – `../helm/homework` does not exist; the chart is in `../helm`.
- `terraform/providers.tf:1-3` – there is no `required_providers` block, so `terraform init` downloads the latest provider versions. With the current helm provider (v3) the `kubernetes {}` block (`providers.tf:10`) and the `set {}` blocks (`main.tf:12`, `main.tf:17`) are invalid syntax too.

**Why it matters:** nothing can be planned or applied, and even after fixing the syntax the next `init` could break it again.
**How to fix:** pin the provider versions in `required_providers`, commit `.terraform.lock.hcl`, and run `terraform fmt` and `terraform validate` before every push.

## 2. The app is unreachable even when the pods run

- `helm/templates/service.yaml:7` – the selector is `app: myapps`, but the pods are labelled `app: myapp`, so the Service has no endpoints.
- `helm/templates/ingress.yaml:17` – the Ingress points to a Service called `homeworks`, which does not exist.
- `helm/templates/deployment.yaml:23` – `containerPort: 5000`, while the Service sends traffic to `8080` (`service.yaml:10`) and `values.yaml` says `8080` as well.

**Why it matters:** every request fails – and `helm lint` passes on this chart, so the linter will not catch it for you.
**How to fix:** don't type the same name twice. Generate names and labels in `templates/_helpers.tpl` and include them in the Deployment, Service and Ingress; name the container port (`http`) and use `targetPort: http`. Then install the chart on a local cluster (kind, k3d or minikube), check that the Service has endpoints (`kubectl get endpointslices`), and add a `helm test`.

## 3. There is nothing to deploy, and the image reference cannot work

- `app/` only has a README: there is no application code and no Dockerfile.
- `helm/values.yaml:5` – `tag: latest`. For `latest`, Kubernetes defaults to `imagePullPolicy: Always`, so on a local cluster without a registry the pod ends in `ImagePullBackOff`. You also cannot tell which version is running, and "rolling back" to `latest` changes nothing.
- `terraform/variables.tf:9` – `image_tag` is declared but never used.

**How to fix:** write the app and a minimal Dockerfile first. Use an explicit tag (a version or the commit SHA), default it to the chart's `appVersion`, and let CI pass it in through `var.image_tag`.

## 4. "production" gets deployed to whatever cluster is current

- `terraform/main.tf:3` – the namespace is hardcoded to `production`, and `main.tf:19` sets the environment to `prod`, although `var.namespace` and `var.environment` exist.
- `terraform/providers.tf:6` and `:11` – a fixed kubeconfig path with no context, so Terraform uses whichever context happens to be active. That can be a real production cluster.

**Why it matters:** a test run can create a `production` namespace in the wrong cluster.
**How to fix:** use the variables you declared, add a required `kube_context` variable (`config_context` in both providers), and add `validation` blocks so wrong values fail at `plan`, not in the cluster.

## 5. The pipeline is a placeholder

- `.gitlab-ci.yml` – both jobs only `echo`, so the pipeline is always green while nothing is built, tested or deployed, and every branch would "deploy".

**Why it matters:** a green pipeline that checks nothing gives false confidence.
**How to fix:** add jobs that really check something: lint (`terraform fmt -check`, `terraform validate`, `helm lint`), unit tests, image build, `terraform plan`, and `apply` only from the default branch, followed by `helm test`. Points 1 and 2 would then fail the pipeline instead of reaching you later.

## Next steps (after the top 5)

- Add liveness and readiness probes, resource requests and limits, and a `securityContext` (non-root, read-only root filesystem).
- Use the values you defined: `replicas` ignores `replicaCount` (`deployment.yaml:7`), and `service.port` is never used.
- Set `ingressClassName` and make the Ingress optional.
- Give the variables descriptions, fill `outputs.tf`, and plan a remote state backend before CI runs Terraform.
- Run `terraform fmt` (2-space indentation) and switch to `kubernetes_namespace_v1` (the old resource is deprecated).

## Two habits that would have prevented most of this

1. **Run it before you push.** `terraform validate`, `helm template` and one install on a local cluster take a few minutes.
2. **Define every name once.** Most of the broken wiring (`myapps`, `homeworks`, `helm/homework`) comes from typing the same name in several places.

Happy to pair on any of these.
