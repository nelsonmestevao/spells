#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title GitLab Assigned Merge Requests
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🦊

# Documentation:
# @raycast.description Opens My Open MRs page on GitLab

open -u https://gitlab.com/dashboard/merge_requests?assignee_username=nelson.estevao
