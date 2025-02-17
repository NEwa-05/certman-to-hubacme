#! /bin/bash

## get values
IFS=$'\n'; for i in $(kubectl get secret -A --selector controller.cert-manager.io/fao=true --no-headers -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name); do
  NAMESPACE=$(echo $i | awk -F " " '{print $1}')
  echo "ns name: " $NAMESPACE
  SECNAME=$(echo $i | awk -F " " '{print $2}')
  echo "secret name: "  $SECNAME
  DOMAIN=$(kubectl get secret -n $NAMESPACE $SECNAME -o yaml| yq '.metadata.annotations["cert-manager.io/common-name"]')
  echo "domain: "  $DOMAIN
  DOMAIN64=$(echo -e $DOMAIN|base64)
  echo "domain64: "  $DOMAIN64
done

  DOMAIN=$(echo -e $(yq '.metadata.annotations["cert-manager.io/common-name"]' certman-cert.yaml)|base64) 
DOMAIN=$()
STORE=$(echo -e $1|base64)
CERT=$(yq '.data["tls.crt"]' certman-cert.yaml)
KEY=$(yq '.data["tls.key"]' certman-cert.yaml)
SECRETNAME=$(yq '.metadata.name' certman-cert.yaml)
#HUBCERTRESOLVER=$(kubectl get secret -n $2 |grep hub-cert-resolver-account |awk -F" " '{print $2}')
HUBCERTRESOLVER="hub-cert-resolver-account-08809529eaab1be95aa0733055a642ca"

## Gen secret

tee testcert.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRETNAME}-hub-acmecert
  namespace: $2
  labels:
    app.kubernetes.io/component: acme-certificate
    app.kubernetes.io/managed-by: traefik-hub
    hub.traefik.io/resolver-name: $1
  ownerReferences:
  - apiVersion: v1
    kind: Secret
    name: ${HUBCERTRESOLVER}
type: kubernetes.io/tls
data:
  domain: ${DOMAIN}
  store: ${STORE}
  tls.crt: ${CERT}
  tls.key: ${KEY}
EOF
