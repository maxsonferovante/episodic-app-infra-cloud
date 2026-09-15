# Episodic — Infrastructure

Terraform for the Episodic backend on AWS: API Gateway, Lambda functions,
DynamoDB and a scheduled sync job.

## What it creates

- **API Gateway (REST)** — `/api/v1/*` routes (auth, series, library, episodes,
  dashboard, history, calendar), CORS, and stage-wide throttling
  (60 req/min = 1 req/s, burst 20).
- **Lambda** — `auth`, `catalog`, `library`, `progress`, `dashboard`, `sync-job`
  (deployed from the zips built by the backend repo).
- **DynamoDB** — single table `EpisodicEpisodes` (`PK`/`SK`) with a `GSI1`
  (`GSI1PK`/`GSI1SK`).
- **EventBridge** — daily rule that invokes the sync job.
- **IAM** — execution roles and least-privilege DynamoDB access.

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
