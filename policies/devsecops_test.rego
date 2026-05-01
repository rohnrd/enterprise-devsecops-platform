package devsecops

# ---------------------------------------------------------------------------
# Tests for devsecops.rego policies
# ---------------------------------------------------------------------------

# --- helper data -----------------------------------------------------------
valid_deployment := {
  "kind": "Deployment",
  "spec": {
    "template": {
      "spec": {
        "securityContext": {"runAsNonRoot": true},
        "containers": [{
          "name": "app",
          "image": "ghcr.io/rohnrd/enterprise-devsecops-platform:1.0",
          "securityContext": {"allowPrivilegeEscalation": false},
          "resources": {"limits": {"cpu": "500m", "memory": "256Mi"}}
        }]
      }
    }
  }
}

# --- Test: valid deployment produces no deny messages ----------------------
test_valid_deployment_no_deny {
  count(deny) == 0 with input as valid_deployment
}

# --- Test: :latest tag is denied -------------------------------------------
test_latest_tag_denied {
  count(deny) > 0 with input as object.union(
    valid_deployment,
    {"spec": {"template": {"spec": {"containers": [{
      "name": "app",
      "image": "ghcr.io/rohnrd/enterprise-devsecops-platform:latest",
      "securityContext": {"allowPrivilegeEscalation": false},
      "resources": {"limits": {"cpu": "500m", "memory": "256Mi"}}
    }]}}}}
  )
}

# --- Test: missing resource limits is denied -------------------------------
test_no_limits_denied {
  count(deny) > 0 with input as object.union(
    valid_deployment,
    {"spec": {"template": {"spec": {"containers": [{
      "name": "app",
      "image": "ghcr.io/rohnrd/enterprise-devsecops-platform:1.0",
      "securityContext": {"allowPrivilegeEscalation": false}
    }]}}}}
  )
}

# --- Test: privilege escalation is denied ----------------------------------
test_priv_escalation_denied {
  count(deny) > 0 with input as object.union(
    valid_deployment,
    {"spec": {"template": {"spec": {"containers": [{
      "name": "app",
      "image": "ghcr.io/rohnrd/enterprise-devsecops-platform:1.0",
      "securityContext": {"allowPrivilegeEscalation": true},
      "resources": {"limits": {"cpu": "500m", "memory": "256Mi"}}
    }]}}}}
  )
}
