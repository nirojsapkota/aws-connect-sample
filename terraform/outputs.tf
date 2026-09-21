output "connect_instance_id" {
  description = "ID of the Amazon Connect instance"
  value       = aws_connect_instance.this.id
}

output "connect_instance_arn" {
  description = "ARN of the Amazon Connect instance"
  value       = aws_connect_instance.this.arn
}

output "connect_instance_access_url" {
  description = "URL agents/admins use to log in to the Connect instance"
  value       = "https://${var.instance_alias}.my.connect.aws/home"
}

output "connect_ccp_url" {
  description = "Contact Control Panel (CCP) URL to embed in the sample web app"
  value       = "https://${var.instance_alias}.my.connect.aws/ccp-v2"
}

output "sample_queue_id" {
  description = "ID of the sample queue"
  value       = aws_connect_queue.sample.queue_id
}

output "sample_contact_flow_id" {
  description = "ID of the sample inbound contact flow"
  value       = aws_connect_contact_flow.sample_inbound.contact_flow_id
}

output "customer_lookup_lambda_arn" {
  description = "ARN of the customer-lookup Lambda function invoked by the flow"
  value       = aws_lambda_function.customer_lookup.arn
}

output "claimed_phone_number" {
  description = "Claimed phone number (E.164), if var.claim_phone_number = true"
  value       = var.claim_phone_number ? aws_connect_phone_number.sample[0].phone_number : null
}

output "admin_username" {
  description = "Username of the default Connect admin user"
  value       = aws_connect_user.admin.name
}
