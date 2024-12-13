terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Declare your domain variable
variable "root_domain_name" {
  type    = string
  default = "galazkar.com"
}

# Declare a variable for the test domain
variable "test_domain_name" {
  type    = string
  default = "test.galazkar.com"
}

# S3 bucket resource for hosting the website
resource "aws_s3_bucket" "website_bucket" {
  bucket = "galazkar.com"
}

# S3 bucket resource for hosting the test website
resource "aws_s3_bucket" "test_website_bucket" {
  bucket = "test.galazkar.com"
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "website_bucket_ownership_controls" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket ownership controls for test website
resource "aws_s3_bucket_ownership_controls" "test_website_bucket_ownership_controls" {
  bucket = aws_s3_bucket.test_website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "website_bucket_public_access_block" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket public access block for test website
resource "aws_s3_bucket_public_access_block" "test_website_bucket_public_access_block" {
  bucket = aws_s3_bucket.test_website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACM certificate resource for galazkar.com and *.galazkar.com using DNS validation
resource "aws_acm_certificate" "website_ssl_cert" {
  domain_name               = "galazkar.com"
  subject_alternative_names = ["*.galazkar.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM certificate resource for test.galazkar.com
resource "aws_acm_certificate" "test_website_ssl_cert" {
  domain_name       = "test.galazkar.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53 Hosted Zone data
data "aws_route53_zone" "selected_zone" {
  name         = var.root_domain_name
  private_zone = false
}

# Route 53 DNS records for certificate validation
resource "aws_route53_record" "cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.website_ssl_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected_zone.zone_id
}

# Route 53 DNS records for test certificate validation
resource "aws_route53_record" "test_cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.test_website_ssl_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected_zone.zone_id
}

# Handle certificate validation once DNS records are created
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.website_ssl_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
  
  timeouts {
    create = "1h"
  }
}

# Handle test certificate validation
resource "aws_acm_certificate_validation" "test_cert_validation" {
  certificate_arn         = aws_acm_certificate.test_website_ssl_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.test_cert_validation_record : record.fqdn]
  
  timeouts {
    create = "1h"
  }
}

# CloudFront origin access identity
resource "aws_cloudfront_origin_access_identity" "website_oai" {
  comment = "CloudFront Origin Access Identity for website distribution"
}

# CloudFront origin access identity for test website
resource "aws_cloudfront_origin_access_identity" "test_website_oai" {
  comment = "CloudFront Origin Access Identity for test website distribution"
}

# CloudFront distribution for the website
resource "aws_cloudfront_distribution" "website_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "s3-website-bucket"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website_oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-website-bucket"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 1200
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  aliases = ["www.${var.root_domain_name}", "${var.root_domain_name}"]

  provisioner "local-exec" {
    command = "echo 'Website URL: ${aws_cloudfront_distribution.website_distribution.domain_name}'"
  }
}

# CloudFront distribution for the test website
resource "aws_cloudfront_distribution" "test_website_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.test_website_bucket.bucket_regional_domain_name
    origin_id   = "s3-test-website-bucket"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.test_website_oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-test-website-bucket"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 1200
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.test_cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  aliases = ["test.${var.root_domain_name}"]

  provisioner "local-exec" {
    command = "echo 'Test Website URL: ${aws_cloudfront_distribution.test_website_distribution.domain_name}'"
  }
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess",
        Effect    = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.website_oai.iam_arn
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

# S3 bucket policy to allow CloudFront access for test website
resource "aws_s3_bucket_policy" "test_website_bucket_policy" {
  bucket = aws_s3_bucket.test_website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess",
        Effect    = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.test_website_oai.iam_arn
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.test_website_bucket.arn}/*"
      }
    ]
  })
}

# Route 53 A record for root domain
resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = "galazkar.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route 53 A record for www subdomain
resource "aws_route53_record" "www_website" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = "www.galazkar.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route 53 A record for test domain
resource "aws_route53_record" "test_website" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = "test.galazkar.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.test_website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.test_website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Variable for S3 bucket object creation
variable "create_bucket_objects" {
  type    = bool
  default = true
}

# Variable for test S3 bucket object creation
variable "create_test_bucket_objects" {
  type    = bool
  default = true
}

# S3 Bucket Object for index.html
resource "aws_s3_bucket_object" "index_html" {
  count  = var.create_bucket_objects ? 1 : 0
  bucket = aws_s3_bucket.website_bucket.id
  key    = "index.html"
  content_type = "text/html"
  source = "${path.module}/../galazkar.com/index.html"
}

# S3 Bucket Object for index.js
resource "aws_s3_bucket_object" "index_js" {
  count         = var.create_bucket_objects ? 1 : 0
  bucket        = aws_s3_bucket.website_bucket.id
  key           = "index.js"
  content_type  = "application/javascript"
  source = "${path.module}/../galazkar.com/index.js"
}

# S3 Bucket Object for styles.css
resource "aws_s3_bucket_object" "styles_css" {
  count  = var.create_bucket_objects ? 1 : 0
  bucket = aws_s3_bucket.website_bucket.id
  key    = "styles.css"
  content_type = "text/css"
  source = "${path.module}/../galazkar.com/styles.css"
}

# S3 Bucket Object resources for test website
resource "aws_s3_bucket_object" "test_index_html" {
  count        = var.create_test_bucket_objects ? 1 : 0
  bucket       = aws_s3_bucket.test_website_bucket.id
  key          = "index.html"
  content_type = "text/html"
  source       = "${path.module}/../galazkar.com/index.html"
}

resource "aws_s3_bucket_object" "test_index_js" {
  count         = var.create_test_bucket_objects ? 1 : 0
  bucket        = aws_s3_bucket.test_website_bucket.id
  key           = "index.js"
  content_type  = "application/javascript"
  source        = "${path.module}/../galazkar.com/index.js"
}

resource "aws_s3_bucket_object" "test_styles_css" {
  count         = var.create_test_bucket_objects ? 1 : 0
  bucket        = aws_s3_bucket.test_website_bucket.id
  key           = "styles.css"
  content_type  = "text/css"
  source        = "${path.module}/../galazkar.com/styles.css"
}

# S3 Bucket Object resources for images in main website
resource "aws_s3_bucket_object" "images" {
  for_each      = var.create_bucket_objects ? fileset("${path.module}/../galazkar.com/images/", "**") : []
  bucket        = aws_s3_bucket.website_bucket.id
  key           = "images/${each.value}"
  content_type  = lookup({
    ".jpg"  = "image/jpeg",
    ".jpeg" = "image/jpeg", 
    ".png"  = "image/png",
    ".gif"  = "image/gif",
    ".webp" = "image/webp",
    ".svg"  = "image/svg+xml"
  }, lower(element(reverse(split(".", each.value)), 0)), "application/octet-stream")
  source        = "${path.module}/../galazkar.com/images/${each.value}"
}

# S3 Bucket Object resources for images in test website
resource "aws_s3_bucket_object" "test_images" {
  for_each      = var.create_test_bucket_objects ? fileset("${path.module}/../galazkar.com/images/", "**") : []
  bucket        = aws_s3_bucket.test_website_bucket.id
  key           = "images/${each.value}"
  content_type  = lookup({
    ".jpg"  = "image/jpeg",
    ".jpeg" = "image/jpeg", 
    ".png"  = "image/png",
    ".gif"  = "image/gif",
    ".webp" = "image/webp",
    ".svg"  = "image/svg+xml"
  }, lower(element(reverse(split(".", each.value)), 0)), "application/octet-stream")
  source        = "${path.module}/../galazkar.com/images/${each.value}"
}