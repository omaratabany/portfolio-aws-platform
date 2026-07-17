# Public static hosting for the status page. Deliberately a separate
# bucket from the ingest pipeline's data bucket (which blocks all public
# access on purpose) — mixing "public website content" and "private data
# lake" in one bucket would mean every future change to one has to be
# checked against the other's very different access requirements.

resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-${var.environment}-status-site-${var.account_id}"
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadOnly"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  content_type = "text/html"

  # Bakes the real API endpoint into the page at apply time, so there's
  # no separate manual edit-and-redeploy step after the API exists.
  content = replace(
    file("${path.root}/../site/index.html"),
    "const API_BASE = \"\";",
    "const API_BASE = \"${var.api_base}\";"
  )

  etag = md5(replace(
    file("${path.root}/../site/index.html"),
    "const API_BASE = \"\";",
    "const API_BASE = \"${var.api_base}\";"
  ))
}
