# Adding --insecure flag to the argocd-server container because we are using self-signed certificates
kubectl patch deployment argocd-server -n <namespace> \
--type='json' \
-p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--insecure"
}]'

# Install Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Waiting for the deployment to be read
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

# adding --enable-ssl-passthrough flag to the ingress-nginx-controller container
# because we are using self-signed certificates
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
--type='json' \
-p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--enable-ssl-passthrough"
}]'

kubectl apply -f manifests/argocd.ingress.yaml