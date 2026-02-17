# CLAUDE.md

## Project Overview

This is a **CircleCI-driven infrastructure automation project** for the RaiseTech training program. It provisions AWS infrastructure via CloudFormation, configures EC2 instances using Ansible, deploys a Rails application ([raisetech-live8-sample-app](https://github.com/yuta-ushijima/raisetech-live8-sample-app)), and validates the deployment with Serverspec tests.

There is no application source code in this repository. This repo contains only infrastructure-as-code, configuration management, CI/CD pipelines, and infrastructure tests.

## Repository Structure

```
.circleci/
  config.yml              # CircleCI pipeline (workflows, jobs, orbs)
ansible/
  playbook.yml            # Main Ansible playbook (entry point)
  inventory               # Ansible inventory (target hosts)
  roles/
    01_yum/               # System package updates and build tools
    02_ruby/              # Ruby installation via rbenv (3.1.2)
    03_bundler/           # Bundler gem manager (2.3.14)
    04_rails/             # Rails framework (7.1.3.2)
    05_node/              # Node.js runtime
    06_yarn/              # Yarn package manager (1.22.19)
    07_mysql/             # MySQL 8.0 database
    08_app/               # Rails application deployment and config
    09_nginx/             # Nginx reverse proxy setup
cloudformation/
  service.yml             # AWS CloudFormation template (VPC, EC2, ALB, S3, IAM, security groups)
serverspec/
  Gemfile                 # Ruby dependencies for infrastructure tests
  Rakefile                # Rake tasks for running serverspec
  spec/
    spec_helper.rb        # Serverspec SSH configuration
    18.179.174.216/
      sample_spec.rb      # Infrastructure verification tests
```

## Technology Stack

| Layer | Technology |
|---|---|
| CI/CD | CircleCI 2.1 |
| Infrastructure | AWS CloudFormation (VPC, EC2, ALB, RDS, S3, IAM) |
| Config Management | Ansible 2.10.7 |
| Application | Ruby 3.1.2, Rails 7.1.3.2, Unicorn |
| Web Server | Nginx (reverse proxy to Unicorn socket) |
| Database | MySQL 8.0 |
| Frontend Assets | Node.js 16.x, Yarn 1.22.19 |
| Infra Testing | Serverspec (RSpec-based) |
| AWS Region | ap-northeast-1 (Tokyo) |

## CircleCI Pipeline

Defined in `.circleci/config.yml`. Uses these orbs:
- `circleci/aws-cli@4.1.2`
- `orbss/ansible-playbook@0.0.5`
- `circleci/ruby@2.1.1`

### Workflow: `RaiseTech`

```
execute-ansible  -->  execute-serverspec (depends on ansible)
```

**Jobs:**
1. **execute-ansible** - Runs `ansible/playbook.yml` against the inventory with `ec2-user` over SSH
2. **execute-serverspec** - Installs Ruby 3.2.3, installs gems from `serverspec/`, runs `bundle exec rspec`

There is also a `test` job defined (not currently in the workflow) that runs RSpec tests using a `circleci/ruby:3.1.2` Docker image.

## CloudFormation Resources

The template in `cloudformation/service.yml` provisions:

- **Network**: VPC (10.0.0.0/16), 2 public subnets (1a, 1c), 1 private subnet, Internet Gateway, route tables, VPC S3 endpoint
- **Compute**: 2x EC2 t2.micro instances (Amazon Linux 2) with IAM instance profiles
- **Load Balancer**: Internet-facing ALB with HTTP listener on port 80, target group routing to both EC2 instances
- **Storage**: S3 bucket with versioning enabled, public access blocked
- **Security**: Separate security groups for EC2 (ports 80/22), RDS (port 3306), and ALB (port 80)
- **Secrets**: Secrets Manager for RDS master user credentials
- **IAM**: Role with S3FullAccess for EC2 instances

### CloudFormation Parameters

- `CIDRIP` - Your IP for SSH/HTTP access restrictions
- `Prefix` - Resource name prefix
- `S3BucketName` - S3 bucket name (default: `raise-tech-s3-bucket`)
- `EC2InstanceAMI` - AMI ID (default: latest Amazon Linux 2)

## Ansible Configuration

Entry point: `ansible/playbook.yml`

- **Target**: `web_server` group from `ansible/inventory`
- **User**: `ec2-user` with sudo
- Roles execute sequentially by numeric prefix (01 through 09)

### Required Environment Variables

These must be set in the CI environment or on the control machine:

| Variable | Purpose |
|---|---|
| `AWS_ALB_HOST` | ALB hostname for Rails host validation |
| `AWS_EC2_HOST` | EC2 hostname |
| `AWS_DB_USER` | Database username |
| `AWS_DB_PW` | Database password |
| `AWS_DB_HOST` | Database host endpoint |
| `AWS_S3_BUCKET` | S3 bucket name for Active Storage |

### Pinned Versions

- Ruby: 3.1.2
- Bundler: 2.3.14
- Rails: 7.1.3.2
- Yarn: 1.22.19
- MySQL: 8.0
- Ansible: 2.10.7
- Application path: `/var/www/raisetech-live8-sample-app`

## Serverspec Tests

Located in `serverspec/spec/18.179.174.216/sample_spec.rb`. Tests validate:

- Ruby 3.1.2 is installed (via rbenv)
- Rails 7.1.3.2 gem is installed
- Node.js is available
- Nginx service is running
- Unicorn gem is installed
- Nginx config file exists at `/etc/nginx/conf.d/rails.conf`
- Port 80 is listening
- HTTP request to localhost:80 returns status 200

Run locally with:
```bash
cd serverspec && bundle install && bundle exec rspec
```

## Key Conventions

### Ansible Roles
- Roles are numbered (`01_`, `02_`, ...) to indicate execution order
- Each role follows the standard Ansible directory layout: `tasks/`, `vars/`, `templates/`
- Jinja2 templates (`.j2`) are used for dynamic configuration files (database.yml, nginx config, unicorn.rb)
- Sensitive values come from environment variables via `lookup('env', ...)`

### Naming
- Ansible variables: `snake_case` (e.g., `ruby_version`, `sample_app_dir`)
- CloudFormation resources: `PascalCase` (e.g., `RaiseTechVPC`, `SecurityGroupEC2`)
- Environment variables: `SCREAMING_SNAKE_CASE` with `AWS_` prefix

### File Formats
- All infrastructure code is YAML
- Serverspec tests are Ruby (RSpec syntax)
- No linter or formatter configuration exists in this repository

## Common Tasks

### Deploying Infrastructure
1. Deploy CloudFormation stack: `aws cloudformation deploy --template-file cloudformation/service.yml --stack-name <name> --parameter-overrides ...`
2. Update `ansible/inventory` with the new EC2 IP address
3. Set required environment variables
4. Run Ansible: `ansible-playbook ansible/playbook.yml -u ec2-user -i ansible/inventory`

### Running Serverspec Locally
```bash
cd serverspec
bundle install
bundle exec rspec
```

### Modifying Ansible Roles
- Each role lives in `ansible/roles/<NN>_<name>/tasks/main.yml`
- Templates go in the role's `templates/` directory
- Variables go in the role's `vars/main.yml` or the playbook's `vars` section
- Test changes by running the playbook with a specific tag: `ansible-playbook ansible/playbook.yml -u ec2-user -i ansible/inventory --tags <role_tag>`

## Notes for AI Assistants

- This repo has **no application source code** -- the Rails app is cloned from GitHub during Ansible provisioning (role `08_app`)
- IP addresses in inventory and serverspec are deployment-specific and will change across environments
- SSH keys referenced (`kawakami.pem`, CircleCI fingerprint) are external secrets not stored in this repo
- The `test` job in `.circleci/config.yml` is defined but not included in the workflow
- CloudFormation outputs export values for cross-stack references (VPC ID, subnet IDs, security group IDs)
