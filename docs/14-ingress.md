# Ingress in Kubernetes

## Overview

Ingress is a Kubernetes resource that manages external access to services inside a cluster.

It acts as a central entry point for HTTP and HTTPS traffic and provides routing rules to direct requests to the appropriate services.

Ingress solves the problem of exposing multiple applications without creating separate NodePorts or LoadBalancers for each application.

---

# Why Ingress Was Introduced

Before Ingress, applications were typically exposed using:

* NodePort
* LoadBalancer

Example:

```text
PHP Application    -> NodePort 30080
Grafana            -> NodePort 30081
Prometheus         -> NodePort 30082
Jenkins            -> NodePort 30083
```

Users would access applications using:

```text
http://192.168.56.10:30080
http://192.168.56.10:30081
http://192.168.56.10:30082
```

Problems:

* Difficult to remember ports
* Not scalable
* Requires one NodePort per application
* LoadBalancer services can become expensive in cloud environments
* No centralized traffic management

Kubernetes introduced Ingress to solve these challenges.

---

# What Problem Does Ingress Solve?

Ingress provides:

* Single entry point for applications
* Host-based routing
* Path-based routing
* HTTPS/TLS termination
* Centralized traffic management
* Reduced operational complexity

Instead of:

```text
app.company.com:30080
grafana.company.com:30081
jenkins.company.com:30082
```

Users can access:

```text
app.company.com
grafana.company.com
jenkins.company.com
```

using standard HTTP (80) and HTTPS (443).

---

# Kubernetes Networking Components

Understanding the difference between Service and Ingress is very important.

## Service

A Service exposes Pods inside the cluster and provides load balancing.

Example:

```text
php-service
    |
    +---- php-pod-1
    +---- php-pod-2
    +---- php-pod-3
```

A Service decides:

> Which Pod should receive traffic?

---

## Ingress

Ingress routes external traffic to Services.

Example:

```text
crud.local
     |
     +---- php-service

grafana.local
     |
     +---- grafana-service
```

An Ingress decides:

> Which Service should receive traffic?

---

# What is an Ingress Controller?

Ingress itself is only a set of routing rules.

It does not process traffic.

An Ingress Controller is responsible for:

* Reading Ingress resources
* Processing requests
* Routing traffic to backend services

Popular Ingress Controllers:

* NGINX Ingress Controller
* Traefik
* HAProxy
* Kong
* AWS ALB Controller

The most commonly used controller is:

```text
NGINX Ingress Controller
```

---

# Ingress vs Ingress Controller

## Ingress

Contains routing rules.

Example:

```yaml
kind: Ingress
```

Defines:

```text
crud.local -> php-service
grafana.local -> grafana-service
```

---

## Ingress Controller

Actual software running inside Kubernetes.

Usually deployed as Pods.

Responsible for:

* Listening on HTTP/HTTPS ports
* Reading Ingress resources
* Routing requests to services

---

# Traffic Flow Without Ingress

```text
Browser
   |
NodePort Service
   |
Pods
```

Example:

```text
192.168.56.10:30080
```

---

# Traffic Flow With Ingress

```text
Browser
   |
Ingress Controller
   |
Service
   |
Pods
```

Example:

```text
crud.local
```

---

# Host-Based Routing

Ingress can route traffic based on hostname.

Example:

```text
crud.local
grafana.local
prometheus.local
```

Traffic Flow:

```text
Browser
    |
    |
NGINX Ingress Controller
    |
    +---- crud.local
    |          |
    |      php-service
    |
    +---- grafana.local
    |          |
    |      grafana-service
    |
    +---- prometheus.local
               |
         prometheus-service
```

---

# Example Host-Based Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: platform-ingress

spec:
  ingressClassName: nginx

  rules:

  - host: crud.local

    http:
      paths:
      - path: /
        pathType: Prefix

        backend:
          service:
            name: php-service

            port:
              number: 80

  - host: grafana.local

    http:
      paths:
      - path: /
        pathType: Prefix

        backend:
          service:
            name: grafana-service

            port:
              number: 3000
```

---

# Path-Based Routing

Ingress can also route traffic using URL paths.

Example:

```text
company.local/
company.local/grafana
company.local/prometheus
```

Traffic Flow:

```text
company.local
      |
      +---- /
      |       |
      |   php-service
      |
      +---- /grafana
      |       |
      |   grafana-service
      |
      +---- /prometheus
              |
        prometheus-service
```

---

# Example Path-Based Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: company-ingress

spec:
  ingressClassName: nginx

  rules:

  - host: company.local

    http:
      paths:

      - path: /
        pathType: Prefix

        backend:
          service:
            name: php-service

            port:
              number: 80

      - path: /grafana
        pathType: Prefix

        backend:
          service:
            name: grafana-service

            port:
              number: 3000
```

---

# How DNS Works With Ingress

Hosts file example:

```text
192.168.56.10 crud.local
192.168.56.10 grafana.local
192.168.56.10 prometheus.local
```

All hostnames point to the same IP address.

Ingress Controller examines the HTTP Host header and forwards traffic to the correct service.

Example:

```http
Host: grafana.local
```

Traffic is routed to:

```text
grafana-service
```

---

# HTTPS and TLS Termination

One major advantage of Ingress is HTTPS management.

Without Ingress:

```text
Application 1 -> Own Certificate
Application 2 -> Own Certificate
Application 3 -> Own Certificate
```

With Ingress:

```text
Browser
    |
 HTTPS (443)
    |
Ingress Controller
    |
    +---- Application 1
    +---- Application 2
    +---- Application 3
```

The Ingress Controller manages SSL certificates and decrypts traffic before forwarding requests to backend services.

This process is called:

```text
TLS Termination
```

---

# Real-World Architecture

```text
Internet
    |
Load Balancer
    |
NGINX Ingress Controller
    |
    +---- frontend-service
    +---- backend-service
    +---- grafana-service
    +---- prometheus-service
    +---- argocd-server
```

Benefits:

* Single public endpoint
* Centralized traffic routing
* Easier management
* Cost efficient
* Supports hundreds of applications

---

# Summary

| Component          | Purpose                                   |
| ------------------ | ----------------------------------------- |
| Pod                | Runs application containers               |
| Service            | Exposes Pods and load balances traffic    |
| NodePort           | Exposes a Service externally using a port |
| Ingress            | Defines routing rules                     |
| Ingress Controller | Implements and processes Ingress rules    |
| DNS                | Resolves hostname to Ingress endpoint     |

---