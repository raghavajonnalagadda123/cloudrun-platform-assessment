output "service_uri" { value = module.cloud_run.service_uri }
output "runtime_service_account_email" { value = module.cloud_run.runtime_service_account_email }
output "latest_ready_revision" { value = module.cloud_run.latest_ready_revision }
