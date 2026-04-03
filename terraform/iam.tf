# ──────────────────────────────────────────────
# IAM ROLE: Lambda Execution Role
# ──────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach AWS managed policy for CloudWatch logging
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy: Rekognition + S3 permissions
resource "aws_iam_role_policy" "lambda_rekognition_s3" {
  name = "${var.project_name}-rekognition-s3-policy"
  role = aws_iam_role.lambda_exec_role.id
policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RekognitionAccess"
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectFaces",
          "rekognition:DetectText"
        ]
        Resource = "*"
      },
      {
        Sid      = "S3ReadInputs"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.image_inputs.arn}/*"
      },
      {
        Sid    = "S3WriteOutputs"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.analysis_outputs.arn}/*"
      },
      {
        Sid    = "S3PresignInputs"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.image_inputs.arn}/*"
      }
    ]
  })
}