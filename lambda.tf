resource "local_file" "lambda_code" {
  content  = local.lambda_code
  filename = "${path.module}/index.py"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.lambda_code.filename
  output_path = "${path.module}/lambda_function.zip"
  depends_on  = [local_file.lambda_code]
}

resource "aws_lambda_function" "api_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "LambdaFunctionOverHttps"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.10"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }

  depends_on = [
    local_file.lambda_code,
    data.archive_file.lambda_zip
  ]
}

locals {
  lambda_code = <<EOF
import json
import boto3
from typing import Dict, Any

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    '''Provide an event that contains the following keys:
      - operation: one of the operations in the operations dict below
      - tableName: required for operations that interact with DynamoDB
      - payload: a parameter to pass to the operation being performed
    '''
    
    if 'body' in event:
        event = json.loads(event['body'])
        
    operation = event['operation']

    if 'tableName' in event:
        dynamo = boto3.resource('dynamodb').Table(event['tableName'])

    operations = {
        'create': lambda x: dynamo.put_item(**x),
        'read': lambda x: dynamo.get_item(**x),
        'update': lambda x: dynamo.update_item(**x),
        'delete': lambda x: dynamo.delete_item(**x),
        'list': lambda x: dynamo.scan(**x),
        'echo': lambda x: x,
        'ping': lambda x: 'pong'
    }

    if operation in operations:
        response = operations[operation](event.get('payload', {}))
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(response)
        }
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': f'Unrecognized operation "{operation}"'
            })
        }
EOF
}