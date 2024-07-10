#!/bin/bash

v_date=$(date +%d-%m-%Y_%I-%M-%p)

> logs-git-pull-add-commit-push.txt

{
echo -e "\nScript execution started at $v_date . . ."

echo -e "\nPulling changes from GitHub . . .\n"
git pull
echo -e "\nStaging changes of local repository $(pwd) . . .\n"
git add .
echo -e "\nCommitting changes . . .\n"
git commit -m "Committ from $(hostname) on $v_date"
echo -e "\nPushing changes to GitHub . . .\n"
git push
echo -e "\nPushing changes to GitLab . . .\n"
git push origin-gitlab main

echo -e "\nPublic Code Repository details :\n"

echo -e "\nGitHub:"
echo -e "\n	HTTPS : https://github.com/Muthukumar-Subramaniam/pub.git\n"
echo -e "\n	SSH   : git@github.com:Muthukumar-Subramaniam/pub.git\n"

echo -e "\nGitLab:"
echo -e "\n	HTTPS : https://gitlab.com/muthukumar-gitlab/pub.git\n"
echo -e "\n	SSH   : git@gitlab.com:muthukumar-gitlab/pub.git\n"

v_date=$(date +%d-%m-%Y_%I-%M-%p)
echo -e "\nScript execution completed at $v_date .\n"
} &> logs-git-pull-add-commit-push.txt

cat logs-git-pull-add-commit-push.txt
