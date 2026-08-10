# ─── Configuracao e credenciais do banco (owned pelo Terraform) ───────────────
# Separados dos manifestos da app (garageos-config/garageos-secret) para que a
# camada de banco seja autossuficiente e provisionada 100% por IaC.

resource "kubernetes_config_map" "db_config" {
  metadata {
    name      = "garageos-db-config"
    namespace = kubernetes_namespace.garageos.metadata[0].name
  }
  data = {
    POSTGRES_USER = var.postgres_user
    POSTGRES_DB   = var.postgres_db
  }
}

resource "kubernetes_secret" "db_secret" {
  metadata {
    name      = "garageos-db-secret"
    namespace = kubernetes_namespace.garageos.metadata[0].name
  }
  data = {
    POSTGRES_PASSWORD = var.postgres_password
  }
  type = "Opaque"
}

# ─── Manifestos do PostgreSQL aplicados como resources (kubectl_manifest) ──────
# Reaproveitam os YAMLs em infra/manifests, sem local-exec.

resource "kubectl_manifest" "postgres_pvc" {
  yaml_body = file("${path.module}/manifests/postgres-pvc.yaml")

  depends_on = [kubernetes_namespace.garageos]
}

resource "kubectl_manifest" "postgres_service" {
  yaml_body = file("${path.module}/manifests/postgres-service.yaml")

  depends_on = [kubernetes_namespace.garageos]
}

resource "kubectl_manifest" "postgres_statefulset" {
  yaml_body = file("${path.module}/manifests/postgres-statefulset.yaml")

  depends_on = [
    kubectl_manifest.postgres_pvc,
    kubernetes_config_map.db_config,
    kubernetes_secret.db_secret,
  ]
}
