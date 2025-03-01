resource "aws_dynamodb_table" "lambda_api_table" {
  name           = "lambda-apigateway"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Name        = "lambda-apigateway"
    Terraform   = "true"
  }
}