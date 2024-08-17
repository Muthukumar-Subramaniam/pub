#!/bin/bash

v_next_execution_time=$(date -d "+1 hour" +%I:%M" "%p" "%Z" "%d-%m-%Y)

./git-pull-add-commit-push.sh

{
echo -e "Note:\n	This was an automated execution by cronjob from WSL-Ubuntu.\n"
echo -e "	Execution takes place every 1 Hr.\n"
echo -e "	Next Execution Starts at : ${v_next_execution_time}\n"
} >> logs-git-pull-add-commit-push.txt
