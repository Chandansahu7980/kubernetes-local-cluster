# Kubernetes RBAC (Role-Based Access Control)

This document explains Kubernetes RBAC concepts and the hands-on labs completed in this learning series.

## Objective

Understand how Kubernetes controls who can perform which actions on which resources.

- **Who** → ServiceAccount / User
- **What** → Role / ClusterRole
- **Where** → Namespace / Cluster
- **How** → RoleBinding / ClusterRoleBinding

## Core Concepts

### ServiceAccount

A `ServiceAccount` provides an identity for applications or workloads running inside Kubernetes.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer
  namespace: rbac-lab
```

Check the ServiceAccount:

```bash
kubectl get serviceaccount -n rbac-lab
```

### Role

A `Role` defines permissions within a specific namespace.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-lab
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
```

### RoleBinding

A `RoleBinding` connects a subject to a `Role`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: rbac-lab
subjects:
- kind: ServiceAccount
  name: developer
  namespace: rbac-lab
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Flow:

`ServiceAccount → RoleBinding → Role → Permissions`

### ClusterRole

A `ClusterRole` is a cluster-scoped RBAC object. It can define permissions for both namespaced and cluster-scoped resources.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader-global
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
```

### ClusterRoleBinding

A `ClusterRoleBinding` grants the referenced `ClusterRole` across the entire cluster.

```text
ClusterRole + ClusterRoleBinding
        ↓
Cluster-wide access
```

#### ClusterRole + RoleBinding

A `ClusterRole` can also be used with a normal `RoleBinding`.

```text
ClusterRole + RoleBinding
        ↓
Permissions limited to the RoleBinding namespace
```

This is an important interview concept.

## Practice Lab

### Lab 1 — Role + RoleBinding

Created:

- Namespace: `rbac-lab`
- ServiceAccount: `developer`
- Role: `pod-reader`
- RoleBinding: `developer-binding`

Test:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:developer -n rbac-lab
```

Expected: `yes`

Another namespace:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:developer -n default
```

Expected: `no`

**Learning:** Role permissions are namespace-scoped.

### Lab 2 — ClusterRole + ClusterRoleBinding

Demonstrated cluster-level permissions.

```text
ClusterRole
      ↓
ClusterRoleBinding
      ↓
Cluster-wide permissions
```

Cluster-scoped resources include:

- `nodes`
- `namespaces`
- `persistentvolumes`

### Lab 3 — ClusterRole + RoleBinding

Created:

- ClusterRole: `pod-reader-global`
- RoleBinding: `clusterrole-user-binding`
- Namespace: `rbac-lab`

Test:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:clusterrole-user -n rbac-lab
```

Expected: `yes`

Another namespace:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:clusterrole-user -n default
```

Expected: `no`

**Learning:** `ClusterRole + RoleBinding` provides namespaced access.

### Lab 4 — ServiceAccount and Namespace Isolation

Example:

```bash
kubectl auth can-i create pods --as=system:serviceaccount:rbac-lab:developer -n rbac-lab
```

Result: `yes`

But:

```bash
kubectl auth can-i create pods --as=system:serviceaccount:rbac-lab:developer -n default
```

Result: `no`

**Learning:** A `ServiceAccount` does not automatically gain permissions in other namespaces. Permissions come from its RBAC bindings.

### Lab 5 — Secret Access with `resourceNames`

Created:

- Secret: `app-secret`
- Secret: `other-secret`
- ServiceAccount: `app-reader`

Restricted Role:

```yaml
resources:
- secrets
resourceNames:
- app-secret
verbs:
- get
```

Therefore:

- `get app-secret` → YES
- `get other-secret` → NO
- `delete app-secret` → NO

Test:

```bash
kubectl auth can-i get secret/app-secret --as=system:serviceaccount:rbac-lab:app-reader -n rbac-lab
```

Expected: `yes`

```bash
kubectl auth can-i get secret/other-secret --as=system:serviceaccount:rbac-lab:app-reader -n rbac-lab
```

Expected: `no`

**resourceNames:** restricts a permission to a specific named resource.

This is useful for least-privilege access.

### Lab 6 — Final RBAC Design Challenge

Real-world scenario:

- Namespace: `production`
- Application: `payment-api`
- ServiceAccount: `payment-api`

Requirements:

- **Pods**: `get`, `list`, `watch`
- **ConfigMaps**: `get`, `list`
- **Secret**: only `payment-db-secret` with `get`

No permissions for:

- `create pods`
- `delete pods`
- `update configmaps`
- `delete secrets`

No access to:

- `nodes`
- `persistentvolumes`
- `namespaces`

Recommended architecture:

```text
ServiceAccount
      ↓
Role
      ↓
Permissions
      ↓
RoleBinding
      ↓
production namespace
```
Because all requirements are namespace-scoped, `Role + RoleBinding` is the cleanest design.

## RBAC Permissions

Typical rule:

```yaml
apiGroups:
- ""
resources:
- pods
verbs:
- get
- list
- watch
```

Core resources such as Pods, Services, Secrets, and ConfigMaps use:

```yaml
apiGroups:
- ""
```

RBAC resources use:

```yaml
apiGroups:
- rbac.authorization.k8s.io
```

### Common verbs

| Verb | Purpose |
|---|---|
| get | Read one resource |
| list | List resources |
| watch | Watch changes |
| create | Create resources |
| update | Update resources |
| patch | Partially update resources |
| delete | Delete resources |
| deletecollection | Delete multiple resources |

## kubectl auth can-i

One of the most useful RBAC troubleshooting commands.

```bash
kubectl auth can-i <verb> <resource> --as=<identity> -n <namespace>
```

Example:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:developer -n rbac-lab
```

Check all permissions:

```bash
kubectl auth can-i --list --as=system:serviceaccount:rbac-lab:developer -n rbac-lab
```

## Useful Commands

### Roles

```bash
kubectl get roles -n rbac-lab
kubectl describe role <role-name> -n rbac-lab
```

### RoleBindings

```bash
kubectl get rolebindings -n rbac-lab
kubectl describe rolebinding <binding-name> -n rbac-lab
```

### ClusterRoles

```bash
kubectl get clusterroles
kubectl describe clusterrole <clusterrole-name>
```

### ClusterRoleBindings

```bash
kubectl get clusterrolebindings
kubectl describe clusterrolebinding <binding-name>
```

### ServiceAccounts

```bash
kubectl get serviceaccounts -n rbac-lab
kubectl describe serviceaccount <name> -n rbac-lab
```

## Common RBAC Mistakes

### Wrong namespace

```bash
kubectl get role -n <namespace>
kubectl get rolebinding -n <namespace>
```

A `RoleBinding` in one namespace does not grant namespaced permissions in another namespace.

### Wrong roleRef

Verify:

```yaml
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

The referenced object must exist and match the intended `Role` or `ClusterRole`.

### Wrong ServiceAccount identity

Use the correct impersonation format:

```text
system:serviceaccount:<namespace>:<serviceaccount>
```

Example:

```text
system:serviceaccount:rbac-lab:developer
```

### Missing verb

If the Role contains:

```yaml
verbs:
- get
```

it does not automatically grant:

- `create`
- `update`
- `delete`

RBAC permissions are explicit and additive.

### Incorrect ClusterRole assumption

A `ClusterRole` does not always mean cluster-wide access.

- `ClusterRole + RoleBinding` can provide namespaced access.
- `ClusterRole + ClusterRoleBinding` provides cluster-wide access.

## Least Privilege

Give applications only the permissions they actually require.

Example:

```yaml
resources:
- secrets
resourceNames:
- payment-db-secret
verbs:
- get
```

This is better than broad access when the application only needs one Secret.

## Role vs ClusterRole

| Feature | Role | ClusterRole |
|---|---|---|
| Scope | Namespace | Cluster |
| Pod permissions | ✅ | ✅ |
| Cluster resource permissions | ❌ | ✅ |
| Used with RoleBinding | ✅ | ✅ |
| Used with ClusterRoleBinding | ❌ | ✅ |

## RoleBinding vs ClusterRoleBinding

| Feature | RoleBinding | ClusterRoleBinding |
|---|---|---|
| Namespace-scoped permissions | ✅ | ❌ |
| Cluster-wide permissions | ❌ | ✅ |
| Can reference Role | ✅ | ❌ |
| Can reference ClusterRole | ✅ | ✅ |

Remember:

- `Role + RoleBinding` → namespace permissions
- `ClusterRole + RoleBinding` → ClusterRole permissions within binding namespace
- `ClusterRole + ClusterRoleBinding` → cluster-wide permissions

## Interview Questions

**What is RBAC?**

RBAC controls access to Kubernetes resources based on roles and permissions.

**Difference between Role and ClusterRole?**

A `Role` is namespace-scoped. A `ClusterRole` is cluster-scoped.

**Difference between RoleBinding and ClusterRoleBinding?**

A `RoleBinding` grants permissions within a namespace. A `ClusterRoleBinding` grants `ClusterRole` permissions cluster-wide.

**Can a RoleBinding reference a ClusterRole?**

Yes. It grants the `ClusterRole`'s permissions within the `RoleBinding` namespace.

**How do you test RBAC permissions?**

Use `kubectl auth can-i`.

**How do you implement least privilege?**

Grant only the required:

- API groups
- resources
- verbs
- resourceNames
- namespace scope

**Can a ServiceAccount access another namespace?**

Not automatically. It requires an appropriate RBAC binding granting access there.

## Lab Cleanup

Remove the practice namespace:

```bash
kubectl delete namespace rbac-lab
```

Delete cluster-scoped practice objects separately:

```bash
kubectl delete clusterrole <clusterrole-name>
kubectl delete clusterrolebinding <binding-name>
```

Check before deleting:

```bash
kubectl get clusterroles
kubectl get clusterrolebindings
```

## Final Learning Outcome

You should now understand:

- `ServiceAccount` → `Role` / `ClusterRole` → `RoleBinding` / `ClusterRoleBinding` → Permissions
- Namespace-scoped RBAC
- Cluster-scoped RBAC
- ServiceAccounts
- Roles
- ClusterRoles
- RoleBindings
- ClusterRoleBindings
- `resourceNames`
- Least privilege
- `kubectl auth can-i`
- RBAC troubleshooting

## Role vs ClusterRole

| Feature | Role | ClusterRole |
|---|---|---|
| Scope | Namespace | Cluster |
| Pod permissions | ✅ | ✅ |
| Cluster resource permissions | ❌ | ✅ |
| Used with RoleBinding | ✅ | ✅ |
| Used with ClusterRoleBinding | ❌ | ✅ |

## RoleBinding vs ClusterRoleBinding

| Feature | RoleBinding | ClusterRoleBinding |
|---|---|---|
| Namespace-scoped permissions | ✅ | ❌ |
| Cluster-wide permissions | ❌ | ✅ |
| Can reference Role | ✅ | ❌ |
| Can reference ClusterRole | ✅ | ✅ |

Remember:

- `Role + RoleBinding` → namespace permissions
- `ClusterRole + RoleBinding` → `ClusterRole` permissions within the binding namespace
- `ClusterRole + ClusterRoleBinding` → cluster-wide permissions

## Interview Questions

**What is RBAC?**

RBAC controls access to Kubernetes resources based on roles and permissions.

**Difference between Role and ClusterRole?**

A `Role` is namespace-scoped. A `ClusterRole` is cluster-scoped.

**Difference between RoleBinding and ClusterRoleBinding?**

A `RoleBinding` grants permissions within a namespace. A `ClusterRoleBinding` grants `ClusterRole` permissions cluster-wide.

**Can a RoleBinding reference a ClusterRole?**

Yes. It grants the `ClusterRole`'s permissions within the `RoleBinding` namespace.

**How do you test RBAC permissions?**

Use `kubectl auth can-i`.

**How do you implement least privilege?**

Grant only the required:

- API groups
- resources
- verbs
- resourceNames
- namespace scope

**Can a ServiceAccount access another namespace?**

Not automatically. It requires an appropriate RBAC binding granting access there.

## Lab Cleanup

Remove the practice namespace:

```bash
kubectl delete namespace rbac-lab
```

Cluster-scoped practice objects may need separate cleanup:

```bash
kubectl delete clusterrole <clusterrole-name>
kubectl delete clusterrolebinding <binding-name>
```

Check before deleting:

```bash
kubectl get clusterroles
kubectl get clusterrolebindings
```