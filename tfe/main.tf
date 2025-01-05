provider "aws" {
  region = "eu-west-3"
}

resource "aws_s3_bucket" "cv_bucket" {
  bucket        = "mi-cv-online"
  force_destroy = true

  tags = {
    Name        = "CV Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.cv_bucket.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_policy" "cv_bucket_policy" {
  bucket = aws_s3_bucket.cv_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "s3:GetObject",
      Effect    = "Allow",
      Resource  = "${aws_s3_bucket.cv_bucket.arn}/*"
      Principal = "*"
    }]
  })
}

resource "aws_s3_object" "cv_files" {
  for_each = fileset("${path.module}/../site_files", "**")
  bucket   = aws_s3_bucket.cv_bucket.id
  key      = each.value
  source   = "${path.module}/../site_files/${each.value}"
  content_type = lookup({
    ".html" = "text/html",
    ".css"  = "text/css",
    ".js"   = "application/javascript",
    ".png"  = "image/png",
    ".jpg"  = "image/jpeg"
    },
    ".${split(".", each.value)[1]}",
  "application/octect-stream")
}

output "s3_website_url" {
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
  description = "S3 static website URL"
}   