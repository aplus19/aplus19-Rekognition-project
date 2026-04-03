terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ──────────────────────────────────────────────
# S3 BUCKET: Image Inputs
# ──────────────────────────────────────────────
resource "aws_s3_bucket" "image_inputs" {
  bucket        = "${var.project_name}-image-inputs"
  force_destroy = true

  tags = {
    Project = var.project_name
    Role    = "image-inputs"
  }
}
resource "aws_s3_bucket_cors_configuration" "image_inputs_cors" {
  bucket = aws_s3_bucket.image_inputs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "image_inputs_block" {
  bucket                  = aws_s3_bucket.image_inputs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────────
# S3 BUCKET: Analysis Outputs
# ──────────────────────────────────────────────
resource "aws_s3_bucket" "analysis_outputs" {
  bucket        = "${var.project_name}-analysis-outputs"
  force_destroy = true

  tags = {
    Project = var.project_name
    Role    = "analysis-outputs"
  }
}
resource "aws_s3_bucket_cors_configuration" "analysis_outputs_cors" {
  bucket = aws_s3_bucket.analysis_outputs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "analysis_outputs_block" {
  bucket                  = aws_s3_bucket.analysis_outputs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────────
# S3 BUCKET: Web Frontend (Static Website)
# ──────────────────────────────────────────────
resource "aws_s3_bucket" "web_frontend" {
  bucket        = "${var.project_name}-web-frontend"
  force_destroy = true

  tags = {
    Project = var.project_name
    Role    = "web-frontend"
  }
}
resource "aws_s3_bucket_public_access_block" "web_frontend_block" {
  bucket                  = aws_s3_bucket.web_frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "web_frontend_site" {
  bucket = aws_s3_bucket.web_frontend.id

  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

resource "aws_s3_bucket_policy" "web_frontend_public" {
  bucket     = aws_s3_bucket.web_frontend.id
  depends_on = [aws_s3_bucket_public_access_block.web_frontend_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web_frontend.arn}/*"
    }]
  })
}

# ──────────────────────────────────────────────
# S3 EVENT → Lambda trigger on image upload
# ──────────────────────────────────────────────
resource "aws_s3_bucket_notification" "image_upload_trigger" {
  bucket = aws_s3_bucket.image_inputs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_analysis.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_analysis.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_analysis.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".png"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}