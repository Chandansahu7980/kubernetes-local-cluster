# 09 - ConfigMaps & Secrets (Configuration Management)

This document explains how to manage application configuration and sensitive data using ConfigMaps and Secrets in Kubernetes.

---

## 📌 Objective

* Understand ConfigMaps
* Understand Secrets
* Inject configuration into pods
* Separate config from application code

---

# 🧠 Why ConfigMaps & Secrets?

In real applications:

* Config changes frequently
* Code should NOT be modified for config
* Sensitive data must be secured

---

# 🧪 Step 1: Create ConfigMap

```bash
kubectl create configmap app-config --from-literal=APP_ENV=dev
```

---

## 🧪 Verify

```bash
kubectl get configmap
kubectl describe configmap app-config
```

---

## 🧠 What is ConfigMap?

* Stores non-sensitive data
* Key-value pairs
* Used by pods as environment variables or files

---

# 🧪 Step 2: Create Secret

```bash
kubectl create secret generic app-secret --from-literal=DB_PASSWORD=mysecret123
```

---

## 🧪 Verify

```bash
kubectl get secrets
kubectl describe secret app-secret
```

---

## 🧠 What is Secret?

* Stores sensitive data
* Values are base64 encoded
* Used for passwords, tokens, keys

---

# 🧪 Step 3: Use ConfigMap & Secret in Deployment

Edit deployment YAML: (template.spec.containers.env)

```yaml
env:
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: APP_ENV

- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: DB_PASSWORD
```

---

## 🧪 Apply Changes

```bash
kubectl apply -f nginx-deployment.yaml
```

---

# 🧪 Step 4: Verify Inside Pod

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

Inside container:

```bash
echo $APP_ENV
echo $DB_PASSWORD
```

---

## 📌 Expected Output

```text
dev
mysecret123
```

---

# 🧠 How It Works

* Kubernetes injects values at runtime
* No need to modify container image
* Clean separation of config and code

---

# ⚠️ Common Issues

---

## ❌ ConfigMap Not Found

```text
configmap "app-config" not found
```

### Fix:

```bash
kubectl get configmap
```

---

## ❌ Secret Not Working

### Cause:

* Wrong key name

### Fix:

```bash
kubectl describe secret app-secret
```

---

## ❌ Env Not Updated

### Cause:

* Pod not restarted

### Fix:

```bash
kubectl rollout restart deployment nginx
```

---

# 🧠 Best Practices

* Use ConfigMap for non-sensitive data
* Use Secret for passwords, tokens
* Do NOT hardcode values in YAML
* Use version-controlled manifests

---

# 🎯 Outcome

* Configuration separated from code
* Sensitive data handled securely
* Deployment becomes flexible

---

# 📚 Key Learnings

* ConfigMap = configuration
* Secret = sensitive data
* Both injected into pods dynamically

---

# 🔜 Next Step

* Persistent Volumes (storage)
* Data persistence in Kubernetes