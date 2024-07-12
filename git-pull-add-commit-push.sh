#!/bin/bash

v_date=$(date +%d-%m-%Y_%I-%M-%p)

> logs-git-pull-add-commit-push.txt

{
echo -e "\nScript execution started at $v_date . . ."

if ! ping -c 1 google.com &>/dev/null ;then echo "Internet is Down! Execution stopped !";exit;fi

echo -e "\nPulling changes from GitHub . . .\n"
git pull
echo -e "\nStaging changes of local repository $(pwd) . . .\n"
git add .
echo -e "\nCommitting changes . . .\n"
git commit -m "Commit from $(hostname) on $v_date"
echo -e "\nPushing changes to GitHub . . .\n"
git push
echo -e "\nPushing changes to GitLab . . .\n"
git push origin-gitlab main

echo -e "\nPublic Code Repository details :\n"

echo -e "GitHub:"
echo -e "	HTTPS : https://github.com/Muthukumar-Subramaniam/pub.git"
echo -e "	SSH   : git@github.com:Muthukumar-Subramaniam/pub.git"

echo -e "\nGitLab:"
echo -e "	HTTPS : https://gitlab.com/muthukumar-gitlab/pub.git"
echo -e "	SSH   : git@gitlab.com:muthukumar-gitlab/pub.git"

v_date=$(date +%d-%m-%Y_%I-%M-%p)
echo -e "\nScript execution completed at $v_date .\n"
} &> logs-git-pull-add-commit-push.txt

cat logs-git-pull-add-commit-push.txt
