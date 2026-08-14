terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = "http://s3.localhost.localstack.cloud:4566"
  }
}

# ============================================================
# BUCKETS
# ============================================================

resource "aws_s3_bucket" "frontend" {
  for_each = var.frontends

  bucket = each.key

  tags = {
    ManagedBy   = "Terraform"
    Environment = "Local"
  }
}

# ============================================================
# ACESSO PÚBLICO
# ============================================================

resource "aws_s3_bucket_public_access_block" "frontend_access" {
  for_each = aws_s3_bucket.frontend

  bucket = each.value.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ============================================================
# CONFIGURAÇÃO DE WEBSITE
# ============================================================

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  for_each = aws_s3_bucket.frontend

  bucket = each.value.id

  index_document {
    suffix = "index.html"
  }
}

# ============================================================
# ARQUIVOS DOS DESAFIOS
# ============================================================

locals {
  frontend_files = merge([
    for bucket, folder in var.frontends : {
      for file in fileset("${path.module}/${folder}", "**") :
      "${bucket}/${file}" => {
        bucket = bucket
        source = "${path.module}/${folder}/${file}"
        key    = file
      }

      if !startswith(file, ".git/")
      && !startswith(file, ".vscode/")
      && !startswith(file, ".terraform/")
    }
  ]...)
}

resource "aws_s3_object" "frontend_files" {
  for_each = local.frontend_files

  # Referência direta ao bucket.
  # Garante que o bucket seja criado antes do upload.
  bucket = aws_s3_bucket.frontend[each.value.bucket].id

  key    = each.value.key
  source = each.value.source

  content_type = lookup(
    {
      ".html" = "text/html"
      ".css"  = "text/css"
      ".js"   = "application/javascript"
      ".json" = "application/json"
      ".png"  = "image/png"
      ".jpg"  = "image/jpeg"
      ".jpeg" = "image/jpeg"
      ".svg"  = "image/svg+xml"
      ".ico"  = "image/x-icon"
      ".gif"  = "image/gif"
      ".webp" = "image/webp"
    },
    lower(regex("\\.[^.]+$", each.value.key)),
    "application/octet-stream"
  )

  etag = filemd5(each.value.source)
}

# ============================================================
# OUTPUTS
# ============================================================

output "bucket_endpoints" {
  value = {
    for k, v in aws_s3_bucket.frontend :
    k => v.website_endpoint
  }
}