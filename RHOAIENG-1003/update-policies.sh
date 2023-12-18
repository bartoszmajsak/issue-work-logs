#!/bin/bash

apply_policies() {
    local ns=$1
    shift
    local policies=("$@")

    for policy in "${policies[@]}"; do
        # Replace 'default' namespace with the actual namespace name
        local policy_to_apply=${policy//default/$ns}
        kubectl apply -n "$ns" -f - <<< "$policy_to_apply"
    done
}

allow_openshift_ingress_policy=$(cat <<'EOF'
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-openshift-ingress
  namespace: default
  labels:
    opendatahub.io/created-by: RHOAIENG-1003
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              network.openshift.io/policy-group: ingress
  policyTypes:
    - Ingress
EOF
)

allow_traffic_from_dsp_policy=$(cat <<'EOF'
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-traffic-from-data-science-projects
  namespace: default
  labels:
    opendatahub.io/created-by: RHOAIENG-1003
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              opendatahub.io/dashboard: 'true'
  policyTypes:
    - Ingress
EOF
)

service_mesh_member_namespaces=$(kubectl get namespaces -l maistra.io/member-of=istio-system -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v '^istio-system$')

for ns in $service_mesh_member_namespaces; do
    echo "Applying policies to namespace: $ns"
    apply_policies "$ns" "$allow_openshift_ingress_policy" "$allow_traffic_from_dsp_policy"
done
