# certman-to-hubacme

Testing cert-manager to hub distributed acme certs migration. 

## Deploy cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
```

```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true --set prometheus.enabled=false
```

### Deploy issuer

```bash
k apply -f cert-manager/issuer.yaml
```

## Deploy Traefik OSS

### Install OSS via helm

```bash
helm upgrade --install traefik traefik/traefik --create-namespace --namespace traefik-1 --values oss/oss-values.yaml
```

### Set DNS entry

```bash
ADDRECORD='{
  "rrset_type": "CNAME",
  "rrset_name": "*.1.'$CLUSTERNAME'",
  "rrset_ttl": "1800",
  "rrset_values": [
    "'$(kubectl get svc/traefik -n traefik-1 --no-headers | awk {'print $4'})'."
  ]
}'
curl -s -X POST -d $ADDRECORD \
  -H "Authorization: Apikey $GANDIV5_API_KEY" \
  -H "Content-Type: application/json" \
  https://api.gandi.net/v5/livedns/domains/$DOMAINNAME/records
```

### Deploy OSS dashboard ingress

```bash
envsubst < oss/oss-dashboard.yaml | kubectl apply -f -
```

## Deploy app

### Create apps namespace

```bash
kubectl create ns whoami
```

### Gen cert with cert-manager

```bash
envsubst < whoami/cert.yaml | kubectl apply -f -
```

### Deploy whoami and ingress

```bash
kubectl apply -f whoami/whoami.yaml
envsubst < whoami/ingress-oss.yaml | kubectl apply -f -
```

## Deploy Hub

### Create namespace

```bash
kubectl create ns traefik
```

### Create Hub token secret

```bash
kubectl create secret generic hub-license --from-literal=token="${HUB_TOKEN}" -n traefik
```

### deploy Hub

```bash
helm upgrade --install traefik traefik/traefik --create-namespace --namespace traefik --values hub/hub-values.yaml
```

### Set DNS entry

```bash
ADDRECORD='{
  "rrset_type": "CNAME",
  "rrset_name": "*.'$CLUSTERNAME'",
  "rrset_ttl": "1800",
  "rrset_values": [
    "'$(kubectl get svc/traefik -n traefik --no-headers | awk {'print $4'})'."
  ]
}'
curl -s -X POST -d $ADDRECORD \
  -H "Authorization: Apikey $GANDIV5_API_KEY" \
  -H "Content-Type: application/json" \
  https://api.gandi.net/v5/livedns/domains/$DOMAINNAME/records
```

### Deploy dashboard ingress

```bash
envsubst < hub/ingress.yaml | kubectl apply -f -
```

### Set DNS alias for migrated app

```bash
ADDRECORD='{
  "rrset_type": "CNAME",
  "rrset_name": "whoami.1.'$CLUSTERNAME'",
  "rrset_ttl": "1800",
  "rrset_values": [
    "'$(kubectl get svc/traefik -n traefik --no-headers | awk {'print $4'})'."
  ]
}'
curl -s -X POST -d $ADDRECORD \
  -H "Authorization: Apikey $GANDIV5_API_KEY" \
  -H "Content-Type: application/json" \
  https://api.gandi.net/v5/livedns/domains/$DOMAINNAME/records
```

```bash
ADDRECORD='{
  "rrset_type": "CNAME",
  "rrset_name": "whoami.2.'$CLUSTERNAME'",
  "rrset_ttl": "1800",
  "rrset_values": [
    "'$(kubectl get svc/traefik -n traefik --no-headers | awk {'print $4'})'."
  ]
}'
curl -s -X POST -d $ADDRECORD \
  -H "Authorization: Apikey $GANDIV5_API_KEY" \
  -H "Content-Type: application/json" \
  https://api.gandi.net/v5/livedns/domains/$DOMAINNAME/records
```

### change app gateway DNS

```bash
envsubst < whoami/ingresses-hub.yaml | kubectl apply -f -
```
