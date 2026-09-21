variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "instance_alias" {
  description = "Globally-unique alias for the Amazon Connect instance"
  type        = string
  default     = "sample-connect-demo"
}

variable "identity_management_type" {
  description = "Identity management type for the Connect instance (CONNECT_MANAGED, SAML, EXISTING_DIRECTORY)"
  type        = string
  default     = "CONNECT_MANAGED"
}

variable "admin_first_name" {
  description = "First name of the default Connect admin user"
  type        = string
  default     = "Admin"
}

variable "admin_last_name" {
  description = "Last name of the default Connect admin user"
  type        = string
  default     = "User"
}

variable "admin_username" {
  description = "Username for the default Connect admin user"
  type        = string
  default     = "connect-admin"
}

variable "admin_password" {
  description = "Password for the default Connect admin user (must satisfy Connect password policy). Provide via TF_VAR_admin_password or a *.tfvars file kept out of version control."
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Email address for the default Connect admin user"
  type        = string
  default     = "nirojsapkota15@gmail.com"
}

variable "claim_phone_number" {
  description = "Whether to claim a phone number for the instance (incurs cost, requires available inventory in the region)"
  type        = bool
  default     = false
}

variable "phone_number_country_code" {
  description = "Country code for the claimed phone number, e.g. US"
  type        = string
  default     = "US"
}

variable "phone_number_type" {
  description = "Type of phone number to claim (TOLL_FREE or DID)"
  type        = string
  default     = "DID"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "amazon-connect-sample"
    ManagedBy   = "terraform"
    Environment = "demo"
  }
}
