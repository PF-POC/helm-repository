apiVersion: v1
items:
- apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    annotations:
      helm.sh/hook: post-install
    name: test2
    namespace: d2-application-gitops
  spec:
    destination:
      namespace: d2-application-gitops
      server: https://kubernetes.default.svc
    project: default
    sources:
    - chart: gitops-payload
      helm:
        valueFiles:
        - $values/Cluster/non-prod/high-trust/rosa-pub-1/application-teams.yaml
      repoURL: https://pf-poc.github.io/helm-repository
      path: charts
      targetRevision: 1.2.3
    - ref: values
      repoURL: https://github.com/PF-POC/day-2-gitops.git
      targetRevision: HEAD
    syncPolicy:
      automated:
        prune: false
        selfHeal: true
      syncOptions:
      - ApplyOutOfSyncOnly=true
kind: List
metadata:
  resourceVersion: ""

