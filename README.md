# Episodic — Infrastructure

Terraform for the Episodic backend on AWS: API Gateway, Lambda functions,
DynamoDB, an SQS hydrate queue and a scheduled refresh job.

## What it creates

- **API Gateway (REST)** — `/api/v1/*` routes (auth, series, library, episodes,
  dashboard, history, calendar), CORS, and stage-wide throttling
  (60 req/min = 1 req/s, burst 20).
- **Lambda** — `auth`, `catalog`, `library`, `progress`, `dashboard`, `sync-job`,
  `hydrate-worker` (deployed from the zips built by the backend repo).
- **DynamoDB** — single table `EpisodicEpisodes` (`PK`/`SK`) with a `GSI1`
  (`GSI1PK`/`GSI1SK`).
- **SQS** — `episodic-hydrate` queue (SSE, 20s long polling, 360s visibility
  timeout) with a `episodic-hydrate-dlq` dead-letter queue (maxReceiveCount 3).
  A Lambda event source mapping consumes it with `ReportBatchItemFailures` and
  `maximum_concurrency = 5` to protect the TMDB rate limit.
- **EventBridge** — daily rule that invokes the `sync-job` scheduler, which
  enqueues hydrate messages for series that need a refresh.
- **IAM** — execution roles, least-privilege DynamoDB access, `sqs:SendMessage`
  for the library lambda and SQS consume permissions for the hydrate worker.

## Requirements

- Terraform 1.5+
- AWS credentials allowed to manage the resources above
- Backend zips built first:
  `episodic-app-backend/scripts/deploy-all.sh`

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then fill in real values
terraform init
terraform plan
terraform apply
```

## Variables

| Variable | Description |
| --- | --- |
| `aws_region` | AWS region (e.g. `sa-east-1`) |
| `jwt_secret` | HS256 secret for the API's JWTs |
| `google_client_id` | Google OAuth client id |
| `tmdb_api_key` | TMDB API key |
| `tags` | Tags applied to all resources |

## Outputs

| Output | Description |
| --- | --- |
| `api_endpoint` | Base URL of the API — use it as `NEXT_PUBLIC_API_URL` |
| `dynamodb_table_name` | DynamoDB table name |
| `lambda_functions` | Map of logical name → Lambda function name |

## Secrets

`terraform.tfvars` and `*.tfstate` are **gitignored** and must never be
committed — the state contains the JWT secret and the TMDB key. Only
`terraform.tfvars.example` (placeholders) is tracked.

## Related repos

- [episodic-app-backend](https://github.com/maxsonferovante/episodic-app-backend)
- [episodic-app-web](https://github.com/maxsonferovante/episodic-app-web)

## License

MIT © Maxson Almeida
