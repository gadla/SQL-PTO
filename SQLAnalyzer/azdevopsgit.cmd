git config --global user.email "sqlanalyzer@microsoft.com"
git config --global user.name "SQLAnalyzer DevOps Admin"

ECHO SOURCE BRANCH IS %BUILD_SOURCEBRANCH%
IF %BUILD_SOURCEBRANCH% == refs/heads/master (
	ECHO Building master branch so no merge is needed.
	EXIT
)
SET sourceBranch=origin/%BUILD_SOURCEBRANCH:refs/heads/=%
ECHO ADDING CHANGES FROM PIPELINE
git branch %sourceBranch%
ECHO ADDING MODIFIED FILES
git add --all
ECHO CREATING COMMIT
git commit -m "Changes made from Pipeline"
ECHO CHECKING MASTER
git reflog
git checkout -b master HEAD@{0}
git pull --strategy recursive -X theirs origin %BUILD_SOURCEBRANCH%
git pull --strategy recursive -X ours origin master
git add --all
git commit -m "Added from VSTS Pipeline"
git push origin master