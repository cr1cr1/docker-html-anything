# Kubernetes Deployment

## Manual

1. Replace placeholder API keys in `secret.yaml`:
   ```yaml
   stringData:
     ANTHROPIC_API_KEY: "sk-ant-..."
     OPENAI_API_KEY: "sk-..."
   ```

2. Apply:
   ```bash
   kubectl apply -k kubernetes/
   kubectl rollout status deployment/html-anything -n html-anything --timeout=120s
   ```

3. Port-forward to verify:
   ```bash
   kubectl port-forward svc/html-anything 3007:80 -n html-anything
   curl http://localhost:3007
   ```

## FluxCD

Point a `Kustomization` at this directory:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: html-anything
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes
  prune: true
  sourceRef:
    kind: GitRepository
    name: docker-html-anything
  targetNamespace: html-anything
```

Inject the secret via a separate `ExternalSecret` or SealedSecret instead of editing `secret.yaml` in Git.

## ArgoCD

Create an `Application`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: html-anything
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nexu-io/docker-html-anything.git
    targetRevision: HEAD
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: html-anything
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Use ArgoCD secrets or an external secret operator for `ai-keys`; do not commit real keys to Git.

## Optional Networking

Uncomment the desired backend in `kustomization.yaml` `resources`:
- `ingress.yaml` — standard Ingress
- `gateway.yaml` + `httproute.yaml` — Gateway API
