data "aws_caller_identity" "current" {}

#############################
# S3 bucket for call recordings / chat transcripts
#############################
resource "aws_s3_bucket" "connect_storage" {
  bucket        = "connect-storage-${var.instance_alias}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "connect_storage" {
  bucket                  = aws_s3_bucket.connect_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#############################
# Amazon Connect instance
#############################
resource "aws_connect_instance" "this" {
  identity_management_type  = var.identity_management_type
  inbound_calls_enabled     = true
  outbound_calls_enabled    = true
  instance_alias            = var.instance_alias
  contact_flow_logs_enabled = true
  contact_lens_enabled      = true
  early_media_enabled       = true

  tags = var.tags
}

resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "call-recordings"
    }
    storage_type = "S3"
  }
}

resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "chat-transcripts"
    }
    storage_type = "S3"
  }
}

#############################
# Default admin user
#############################
resource "aws_connect_security_profile" "admin" {
  instance_id = aws_connect_instance.this.id
  name        = "SampleAdminProfile"
  description = "Admin profile for the sample Connect instance"

  permissions = [
    "BasicAgentAccess",
    "OutboundCallAccess",
  ]

  tags = var.tags
}

data "aws_connect_hours_of_operation" "basic" {
  instance_id = aws_connect_instance.this.id
  name        = "Basic Hours"
  depends_on  = [aws_connect_instance.this]
}

# Built-in security profile auto-created by Connect for every new instance,
# granting full admin console access (Channels, Flows, Users, etc.).
data "aws_connect_security_profile" "builtin_admin" {
  instance_id = aws_connect_instance.this.id
  name        = "Admin"
  depends_on  = [aws_connect_instance.this]
}

resource "aws_connect_routing_profile" "default" {
  instance_id               = aws_connect_instance.this.id
  name                      = "sample-routing-profile"
  default_outbound_queue_id = aws_connect_queue.sample.queue_id
  description               = "Sample routing profile for demo agents"

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.sample.queue_id
  }

  tags = var.tags
}

resource "aws_connect_user" "admin" {
  instance_id        = aws_connect_instance.this.id
  name               = var.admin_username
  password           = var.admin_password
  routing_profile_id = aws_connect_routing_profile.default.routing_profile_id

  security_profile_ids = [
    data.aws_connect_security_profile.builtin_admin.security_profile_id,
  ]

  identity_info {
    first_name = var.admin_first_name
    last_name  = var.admin_last_name
    email      = var.admin_email
  }

  phone_config {
    phone_type = "SOFT_PHONE"
  }

  tags = var.tags
}

#############################
# Queue
#############################
resource "aws_connect_queue" "sample" {
  instance_id           = aws_connect_instance.this.id
  name                  = "SampleQueue"
  description           = "Sample queue used by the demo inbound flow"
  hours_of_operation_id = data.aws_connect_hours_of_operation.basic.hours_of_operation_id

  tags = var.tags
}

#############################
# Lambda: customer lookup, invoked from the contact flow
#############################
data "archive_file" "customer_lookup" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/customer_lookup"
  output_path = "${path.module}/build/customer_lookup.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.instance_alias}-customer-lookup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "customer_lookup" {
  function_name    = "${var.instance_alias}-customer-lookup"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 8
  filename         = data.archive_file.customer_lookup.output_path
  source_code_hash = data.archive_file.customer_lookup.output_base64sha256

  tags = var.tags
}

resource "aws_lambda_permission" "allow_connect" {
  statement_id   = "AllowExecutionFromConnect"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.customer_lookup.function_name
  principal      = "connect.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_connect_lambda_function_association" "customer_lookup" {
  instance_id  = aws_connect_instance.this.id
  function_arn = aws_lambda_function.customer_lookup.arn
}

#############################
# Contact flow
#############################
resource "aws_connect_contact_flow" "sample_inbound" {
  instance_id = aws_connect_instance.this.id
  name        = "SampleInboundFlow"
  description = "Sample inbound flow: greets caller, looks up customer via Lambda, routes to queue"
  type        = "CONTACT_FLOW"

  content = templatefile("${path.module}/contact_flows/sample_inbound_flow.json.tpl", {
    lambda_arn = aws_lambda_function.customer_lookup.arn
    queue_arn  = aws_connect_queue.sample.queue_id
  })

  depends_on = [aws_connect_lambda_function_association.customer_lookup]

  tags = var.tags
}

#############################
# Optional: claim a phone number and associate it with the flow
#############################
resource "aws_connect_phone_number" "sample" {
  count        = var.claim_phone_number ? 1 : 0
  target_arn   = aws_connect_instance.this.arn
  country_code = var.phone_number_country_code
  type         = var.phone_number_type

  tags = var.tags
}

# Note: associating the claimed number with `aws_connect_contact_flow.sample_inbound`
# must currently be done manually in the Connect admin console (Channels > Phone
# numbers), since the AWS provider does not yet expose a number-to-flow association
# resource.
