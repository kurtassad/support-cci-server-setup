#!/bin/bash

set -e

kubectl delete pod -n circleci-server -l app=nomad-server