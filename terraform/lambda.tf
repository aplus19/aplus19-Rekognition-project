# Auto-zip the Python script for deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/../lambda/handler.zip"
}

# ──────────────────────────────────────────────
# LAMBDA FUNCTION
# ──────────────────────────────────────────────
resource "aws_lambda_function" "image_analysis" {
  function_name    = "${var.project_name}-handler"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.10"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  environment {
    variables = {
      OUTPUT_BUCKET  = aws_s3_bucket.analysis_outputs.bucket
      INPUT_BUCKET   = aws_s3_bucket.image_inputs.bucket
      MIN_CONFIDENCE = tostring(var.min_confidence)
    }
  }

  tags = {
    Project = var.project_name
  }
}
# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_analysis.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_inputs.arn
}

# ──────────────────────────────────────────────
# API GATEWAY (HTTP API)
# ──────────────────────────────────────────────
resource "aws_apigatewayv2_api" "rekognition_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.rekognition_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.image_analysis.invoke_arn
  integration_method = "POST"
}

# POST /analyze  → triggers analysis or returns presigned URL
resource "aws_apigatewayv2_route" "analyze_route" {
  api_id    = aws_apigatewayv2_api.rekognition_api.id
  route_key = "POST /analyze"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# GET /results/{proxy+}  → fetch result JSON from outputs bucket
resource "aws_apigatewayv2_route" "results_route" {
  api_id    = aws_apigatewayv2_api.rekognition_api.id
  route_key = "GET /results/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.rekognition_api.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_analysis.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rekognition_api.execution_arn}/*/*"
}