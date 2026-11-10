mock_provider "google" {}

run "service_uses_expected_name_and_private_ingress" {
  command = plan
  variables {
    project_id                 = "test-project"
    region                     = "us-central1"
    service_name               = "test-api"
    environment                = "dev"
    image                      = "us-central1-docker.pkg.dev/test-project/apps/api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    runtime_service_account_id = "test-api-runtime"
    min_instance_count         = 0
    max_instance_count         = 4
  }
  assert {
    condition     = google_cloud_run_v2_service.service.name == "test-api"
    error_message = "Cloud Run service name must match the input."
  }
  assert {
    condition     = google_cloud_run_v2_service.service.ingress == "INGRESS_TRAFFIC_INTERNAL_ONLY"
    error_message = "Default ingress must be internal-only."
  }
  assert {
    condition     = google_service_account.runtime.account_id == "test-api-runtime"
    error_message = "A dedicated runtime service account must be created."
  }
}

run "rejects_mutable_image_tag" {
  command = plan
  variables {
    project_id                 = "test-project"
    region                     = "us-central1"
    service_name               = "test-api"
    environment                = "dev"
    image                      = "us-central1-docker.pkg.dev/test-project/apps/api:latest"
    runtime_service_account_id = "test-api-runtime"
  }
  expect_failures = [var.image]
}
