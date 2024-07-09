# oc -n vault exec -it vault-0 -- sh 

#!/bin/sh

# Enable the kubernetes auth method
vault auth enable kubernetes


# Write kubernetes auth configuration
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# vault write auth/kubernetes/config \
#     token_reviewer_jwt="<token> \
#     kubernetes_host=https://api.rosa-pub-1.ttrc.p3.openshiftapps.com:443 \
#     kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Enable kv secrets engine
vault secrets enable -version=2 kv

# Create our sample kv
vault kv put kv/vplugin/supersecret username="myuser" password="password"

# Create policy for secret access
vault policy write vplugin - <<EOF
path "kv/*" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/argocd \
    bound_service_account_names=vplugin \
    bound_service_account_namespaces=openshift-gitops \
    policies=vplugin \
    ttl=1h

##########
# PKI
##########

cd /tmp
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write -field=certificate pki/root/generate/internal \
     common_name="business.com" \
     issuer_name="root-2024" \
     ttl=87600h > root_2024_ca.crt
## list issuers
issuers=`vault list pki/issuers/|grep -v "\-\-\-\-"|grep -v Keys`
## read from issuers
vault read pki/issuer/$issuers
vault write pki/roles/getCerts allow_any_name=true
vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int
vault write -format=json pki_int/intermediate/generate/internal \
     common_name="business.com Intermediate Authority" \
     issuer_name="business-dot-com-intermediate" |grep -i csr\": |awk -F\" '{print $4}'|awk '{gsub(/\\n/,"\n")}1' > pki_intermediate.csr
vault write -format=json pki/root/sign-intermediate \
     issuer_ref="root-2024" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" |grep certificate|awk -F\" '{print $4}'|awk '{gsub(/\\n/,"\n")}1' > intermediate.cert.pem
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
vault write pki_int/roles/business-dot-com \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="business.com" \
     allow_subdomains=true \
     max_ttl="720h"
vault write auth/kubernetes/role/vault-issuer-role \
    bound_service_account_names=vault-issuer \
    bound_service_account_namespaces=cert-test \
    audience="vault://cert-test/vault-issuer" \
    policies=pki \
    ttl=1m





