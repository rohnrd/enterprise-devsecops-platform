package devsecops

# ---------------------------------------------------------------------------
# Policy: container image must not use :latest tag
# ---------------------------------------------------------------------------
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf(
    "Container '%v' uses ':latest' image tag. Pin to a specific version.",
    [container.name],
  )
}

# ---------------------------------------------------------------------------
# Policy: containers must define resource limits
# ---------------------------------------------------------------------------
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf(
    "Container '%v' has no resource limits. Define cpu and memory limits.",
    [container.name],
  )
}

# ---------------------------------------------------------------------------
# Policy: containers must not allow privilege escalation
# ---------------------------------------------------------------------------
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.allowPrivilegeEscalation == true
  msg := sprintf(
    "Container '%v' allows privilege escalation. Set allowPrivilegeEscalation: false.",
    [container.name],
  )
}

# ---------------------------------------------------------------------------
# Policy: pod must run as non-root
# ---------------------------------------------------------------------------
deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := "Deployment pod spec must set securityContext.runAsNonRoot: true."
}
