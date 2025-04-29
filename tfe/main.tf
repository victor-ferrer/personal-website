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

resource "aws_cloudfront_distribution" "cv_distribution" {
  origin {
    domain_name = aws_s3_bucket.cv_bucket.website_endpoint
    origin_id = "S3-CV-Origin"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["SSLv3"]
    }
    
  }
  enabled = true
  default_root_object = "index.html"
  restrictions {
    geo_restriction {
      locations = []
      restriction_type = "none"
    } 
  }
  default_cache_behavior {
    allowed_methods = ["GET","HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "S3-CV-Origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      cookies {
        forward = "none"
      }
      query_string = true
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn = "arn:aws:acm:us-east-1:434936001443:certificate/6243b854-d492-4b80-9e06-0c51b4134fc6"
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method = "sni-only"

  }

  aliases = ["www.victorferrerposa.com"]
}

resource "aws_route53_zone" "my_zone" {
  name = "victorferrerposa.com"
}

resource "aws_route53_record" "cv_record" {
  zone_id = aws_route53_zone.my_zone.id
  name = "www"
  type = "CNAME"
  ttl = 300
  records = [aws_cloudfront_distribution.cv_distribution.domain_name]
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

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cv_distribution.domain_name
}