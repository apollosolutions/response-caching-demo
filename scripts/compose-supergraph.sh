#!/usr/bin/env bash
# Regenerates router/supergraph.graphql from the subgraph schemas.
# Requires Rover: https://www.apollographql.com/docs/rover/getting-started
set -euo pipefail
cd "$(dirname "$0")/../router"

rover supergraph compose --config supergraph.yaml --output supergraph.graphql
echo "✓ wrote router/supergraph.graphql"
