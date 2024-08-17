#!/bin/bash
v_date=$(date +%I:%M" "%p" "%Z" "%d-%m-%Y)
v_hostname=$(hostname -f)

{
echo -e "\nExecution of : $(pwd)/$(basename $0)"
echo -e "\nFrom Host : ${v_hostname}"
} > logs-git-pull-add-commit-push.txt

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
echo -e "\nScript execution started at : $(date) . . ."

echo -e "\nPulling changes from GitHub . . .\n"
git pull
echo -e "\nStaging changes of local repository $(pwd) . . .\n"
git add .
echo -e "\nCommitting changes . . .\n"
git commit -m "Commit from ${v_hostname} on $v_date"
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

v_date=$(date +%I:%M" "%p" "%Z" "%d-%m-%Y)
echo -e "\nScript execution completed at : $(date) .\n"
} &>> logs-git-pull-add-commit-push.txt

cat logs-git-pull-add-commit-push.txt
