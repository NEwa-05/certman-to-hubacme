#! /bin/bash

## scale down

kubectl scale --replicas=0 deployment/traefik -n $2

## get values

HUBCERTRESOLVER=$(kubectl get secret -n $2 --no-headers -o custom-columns=NAME:.metadata.name|grep hub-cert-resolver-account)
HUBOWNERUID=$(kubectl get secret -n $2 $HUBCERTRESOLVER -o yaml|yq '.metadata.uid')
IFS=$'\n'; for i in $(kubectl get secret -A --selector controller.cert-manager.io/fao=true --no-headers -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name); do
  NAMESPACE=$(echo $i|awk -F " " '{print $1}')
  SECNAME=$(echo $i|awk -F " " '{print $2}')
  SECCONTENT=$(kubectl get secret -n $NAMESPACE $SECNAME -o yaml)
  DOMAIN=$(printf '%s' "$SECCONTENT"|yq '.metadata.annotations["cert-manager.io/common-name"]')
  JSONDOMAIN64=$(printf {\"main\":\"$DOMAIN\"}|base64)
  STORE64=$(printf 'default'|base64)
  CERT64=$(printf '%s' "$SECCONTENT"|yq '.data["tls.crt"]')
  KEY64=$(printf '%s' "$SECCONTENT"|yq '.data["tls.key"]')
## Gen secret
  kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECNAME}-hub-acmecert
  namespace: $2
  labels:
    app.kubernetes.io/component: acme-certificate
    app.kubernetes.io/managed-by: traefik-hub
    hub.traefik.io/resolver-name: $1
  ownerReferences:
  - apiVersion: v1
    kind: Secret
    name: ${HUBCERTRESOLVER}
    uid: ${HUBOWNERUID}
type: kubernetes.io/tls
data:
  domain: ${JSONDOMAIN64}
  store: ${STORE64}
  tls.crt: ${CERT64}
  tls.key: ${KEY64}

EOF
done

## scale up

kubectl scale --replicas=1 deployment/traefik -n $2