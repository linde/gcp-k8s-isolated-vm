resource "google_artifact_registry_repository" "tunnel_repo" {
  project       = local.gcp_project
  location      = local.region
  repository_id = "tunnel-repo-${local.rand_suffix}"
  description   = "Docker repository for tunnel image"
  format        = "DOCKER"

  depends_on = [
    time_sleep.wait_for_registry_api
  ]
}


resource "google_project_iam_member" "registry_reader" {
  project = local.gcp_project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${local.service_account}"
}

resource "docker_image" "tunnel_image" {
  name = "${google_artifact_registry_repository.tunnel_repo.registry_uri}/tunnel-image:latest"
  build {
    context    = path.module
    dockerfile = "Dockerfile"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "image-files/*") : filesha1("${path.module}/${f}")]))
  }
}


resource "docker_registry_image" "push_tunnel_image" {
  name = docker_image.tunnel_image.name

  triggers = {
    dockerfile_hash = docker_image.tunnel_image.id
  }

}
