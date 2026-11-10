output "service_name" {
  value = google_cloud_run_v2_service.service.name
}
output "service_uri" {
  value = google_cloud_run_v2_service.service.uri
}
output "runtime_service_account_email" {
  value = google_service_account.runtime.email
}
output "latest_ready_revision" {
  value = google_cloud_run_v2_service.service.latest_ready_revision
}
