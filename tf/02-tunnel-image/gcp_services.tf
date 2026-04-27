resource "google_project_service" "artifact_registry" {
  project = local.gcp_project
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

resource "time_sleep" "wait_for_registry_api" {
  depends_on = [google_project_service.artifact_registry]

  create_duration = "30s"
}
