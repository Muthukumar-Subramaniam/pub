#!/bin/bash

v_date=$(date +%d-%m-%Y_%I-%M-%p)

echo -e "\nExecution of : $(pwd)/$(basename $0) "> logs-git-pull-add-commit-push.txt

if ! ping -c 1 github.com &>/dev/null
then 
	{
	echo -e "\nInternet is Down! Execution stopped !\n"
	echo -e "Time of Execution : $v_date \n"
	} &> logs-git-pull-add-commit-push.txt
	cat logs-git-pull-add-commit-push.txt
	exit
fi

{
echo -e "\nScript execution started at $v_date . . ."

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
