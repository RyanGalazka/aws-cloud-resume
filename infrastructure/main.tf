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

# S3 bucket resource
resource "aws_s3_bucket" "website_bucket" {
  bucket = "galazkar.com"
}

# Declare your domain variable
variable "root_domain_name" {
  type    = string
  default = "galazkar.com"
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "website_bucket_ownership_controls" {
  bucket = aws_s3_bucket.website_bucket.id
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

# ACM certificate resource for galazkar.com and *.galazkar.com
resource "aws_acm_certificate" "website_ssl_cert" {
  domain_name       = "galazkar.com"
  subject_alternative_names = ["*.galazkar.com"]
  validation_method = "EMAIL"
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.website_ssl_cert.arn
}

# CloudFront origin access identity
resource "aws_cloudfront_origin_access_identity" "website_oai" {
  comment = "CloudFront Origin Access Identity for website distribution"
}

# CloudFront distribution
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


# Use the fetched hosted zone in the aws_route53_record resources
resource "aws_route53_record" "website" {
  zone_id = "Z0759235VNZD9IJW96OY"
  name    = "galazkar.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_website" {
  zone_id = "Z0759235VNZD9IJW96OY"
  name    = "www.galazkar.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}


variable "create_bucket_objects" {
  type    = bool
  default = true # Set default value to true if you want the objects to be created by default
}

# S3 Bucket Objects
resource "aws_s3_bucket_object" "index_html" {
  count  = var.create_bucket_objects ? 1 : 0
  bucket = aws_s3_bucket.website_bucket.id
  key    = "index.html"
  content_type = "text/html"
  source = "${path.module}/../galazkar.com/index.html"
}

# S3 Bucket Objects for index.js
resource "aws_s3_bucket_object" "index_js" {
  count         = var.create_bucket_objects ? 1 : 0
  bucket        = aws_s3_bucket.website_bucket.id
  key           = "index.js"
  content_type  = "application/javascript"
  source = "${path.module}/../galazkar.com/index.js"
}


resource "aws_s3_bucket_object" "styles_css" {
  count  = var.create_bucket_objects ? 1 : 0
  bucket = aws_s3_bucket.website_bucket.id
  key    = "styles.css"
  content_type = "text/css"
  source = "${path.module}/../galazkar.com/styles.css"
}