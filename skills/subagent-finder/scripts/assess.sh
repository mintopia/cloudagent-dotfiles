#!/usr/bin/env bash
set -euo pipefail

# Scans the current project directory for tech stack signals and outputs
# search keywords suitable for the subagent search script.
# Each line of output is a keyword group (space-separated keywords for one search).

PROJECT_DIR="${1:-.}"

keywords=()

add() { keywords+=("$1"); }

# ----- Language / Runtime Detection -----

[ -f "$PROJECT_DIR/package.json" ] && {
  add "node javascript"
  grep -q '"typescript"' "$PROJECT_DIR/package.json" 2>/dev/null && add "typescript"
  grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null && add "react frontend"
  grep -q '"vue"' "$PROJECT_DIR/package.json" 2>/dev/null && add "vue frontend"
  grep -q '"angular"' "$PROJECT_DIR/package.json" 2>/dev/null && add "angular frontend"
  grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null && add "react frontend"
  grep -qE '"(express|fastify|koa|hapi|nest)"' "$PROJECT_DIR/package.json" 2>/dev/null && add "backend api"
  grep -q '"electron"' "$PROJECT_DIR/package.json" 2>/dev/null && add "electron desktop"
  grep -qE '"(jest|vitest|mocha|cypress|playwright)"' "$PROJECT_DIR/package.json" 2>/dev/null && add "test automation"
}

[ -f "$PROJECT_DIR/go.mod" ] && add "go backend"
[ -f "$PROJECT_DIR/Cargo.toml" ] && add "rust systems"
{ [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ]; } && {
  add "python"
  grep -rqlE "django|flask|fastapi" "$PROJECT_DIR/requirements.txt" "$PROJECT_DIR/pyproject.toml" 2>/dev/null && add "python api backend"
  grep -rqlE "pandas|numpy|scikit|tensorflow|torch|keras" "$PROJECT_DIR/requirements.txt" "$PROJECT_DIR/pyproject.toml" 2>/dev/null && add "data machine learning"
}
[ -f "$PROJECT_DIR/Gemfile" ] && add "ruby rails"
{ [ -f "$PROJECT_DIR/pom.xml" ] || [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; } && add "java spring"
[ -f "$PROJECT_DIR/Package.swift" ] && add "swift ios mobile"
[ -f "$PROJECT_DIR/pubspec.yaml" ] && add "flutter mobile"
(find "$PROJECT_DIR" -maxdepth 2 -name "*.cs" -o -name "*.csproj" 2>/dev/null | grep -q .) && add "dotnet csharp"
(find "$PROJECT_DIR" -maxdepth 2 -name "*.php" -o -name "composer.json" 2>/dev/null | grep -q .) && add "php"
[ -f "$PROJECT_DIR/mix.exs" ] && add "elixir"

# ----- Infrastructure Detection -----

{ [ -f "$PROJECT_DIR/Dockerfile" ] || [ -f "$PROJECT_DIR/docker-compose.yml" ] || [ -f "$PROJECT_DIR/docker-compose.yaml" ]; } && add "docker container"
(find "$PROJECT_DIR" -maxdepth 3 -name "*.tf" 2>/dev/null | grep -q .) && add "terraform infrastructure"
(find "$PROJECT_DIR" -maxdepth 3 -name "*.hcl" -path "*/terragrunt*" 2>/dev/null | grep -q .) && add "terragrunt infrastructure"
(find "$PROJECT_DIR" -maxdepth 3 -name "kustomization.yaml" -o -name "*.yaml" -path "*/k8s/*" -o -name "*.yaml" -path "*/kubernetes/*" 2>/dev/null | grep -q .) && add "kubernetes deploy"
[ -d "$PROJECT_DIR/.github/workflows" ] && add "deploy pipeline automation"
[ -f "$PROJECT_DIR/.gitlab-ci.yml" ] && add "deploy pipeline automation"
(find "$PROJECT_DIR" -maxdepth 2 -name "serverless.yml" -o -name "serverless.yaml" -o -name "sam.yaml" -o -name "template.yaml" 2>/dev/null | grep -q .) && add "serverless cloud"

# ----- Domain Detection -----

(find "$PROJECT_DIR" -maxdepth 2 -name "*.graphql" -o -name "*.gql" 2>/dev/null | grep -q .) && add "graphql api"
(find "$PROJECT_DIR" -maxdepth 2 -name "*.proto" 2>/dev/null | grep -q .) && add "api grpc"
(find "$PROJECT_DIR" -maxdepth 3 -name "*.sol" 2>/dev/null | grep -q .) && add "blockchain solidity"
[ -f "$PROJECT_DIR/wp-config.php" ] && add "wordpress"

# ----- Always useful -----

[ -d "$PROJECT_DIR/.git" ] && add "code review refactoring"

# ----- Output -----

if [ ${#keywords[@]} -eq 0 ]; then
  echo "general development"
else
  printf '%s\n' "${keywords[@]}"
fi
