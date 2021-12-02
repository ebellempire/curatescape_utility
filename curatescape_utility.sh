#!/bin/sh
SUMMARY=''
NOW=$(date +"%Y-%m-%d-%R")
DIR=~/curatescape_utility
PLUGINS_DIR=~/curatescape_utility/plugins
THEMES_DIR=~/curatescape_utility/themes
SCRIPT_LOCATION=$(pwd)
ME="${0##*/}"

RED='\E[0;31m'
GREEN='\E[0;32m'
YELLOW='\E[0;33m'
CYAN='\E[0;36m'
NOCOLOR='\E[0m'
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

GITHUB_REPOS_PLUGINS=(
	CPHDH/CuratescapeJSON
	CPHDH/CuratescapeAdminHelper
	CPHDH/TourBuilder
	omeka/plugin-Geolocation
	omeka/plugin-SimplePages
	omeka/plugin-SimpleVocab
	ebellempire/MoreUserRoles
	CPHDH/SuperRss
)

GITHUB_REPOS_THEMES=(
	CPHDH/theme-curatescape
)

if [ $# -eq 0 ] 
	then
		echo -e ${RED}"█ Oops, you forgot to include an argument! ${NOCOLOR}\nPlease include at least one path to an existing Omeka installation. Here's an example: \n${YELLOW}sh curatescape_utility.sh path/to/omeka1 path/to/omeka2" ${NOCOLOR}; exit 1;
fi	

echo -e ${CYAN}"Running Curatescape Utility from ${SCRIPT_LOCATION}/${ME}" ${NOCOLOR}


if ! [ -x "$(command -v git)" ]
	then
	
		echo -e ${RED}"█ ERROR: Git is missing or is not executable. Git is required for this utility. Please install Git or use a manual method for adding/updating Curatescape tools." ${NOCOLOR}
		exit 1
			
	else

		echo -e ${GREEN}"█ Git verified ($(git --version))" ${NOCOLOR}
			
			# WORKING DIRECTORIES
			test -d $DIR || mkdir -p $DIR || { echo -e "${RED}█ Unable to create working directory at ${DIR} ${NOCOLOR}"; exit 2; }
			test -d $PLUGINS_DIR || mkdir -p $PLUGINS_DIR || { echo -e "${RED}█ Unable to create plugins working directory at ${PLUGINS_DIR} ${NOCOLOR}"; exit 2; }
			test -d $THEMES_DIR || mkdir -p $THEMES_DIR || { echo -e "${RED}█ Unable to create themes working directory at ${THEMES_DIR} ${NOCOLOR}"; exit 2; }
			
			echo -e ${GREEN}"█ Working directory verified ('${DIR}')" ${NOCOLOR}
			
			# PLUGINS
			echo -e ${GREEN}"█ Checking plugin repos ...\n" ${NOCOLOR}
			for REPO_NAME in "${GITHUB_REPOS_PLUGINS[@]}"			
		    do
			    ### just the repo (removes owner from path)
			    REPO_DIR_PREFIXED=$(echo $REPO_NAME | cut -d "/" -f 2) 
				
			    ### just the plugin (removes plugin- prefix from repo name)
			    REPO_DIR=${REPO_DIR_PREFIXED/plugin-/}	
			    
				if [ ! -d ${PLUGINS_DIR}/${REPO_DIR} ]
				
					then
						echo -e ${CYAN}"█ Cloning '${REPO_NAME}'..." ${NOCOLOR}
						git clone https://github.com/${REPO_NAME}.git ${PLUGINS_DIR}/${REPO_DIR}
						cd ${PLUGINS_DIR}/${REPO_DIR}
						
						latesttag=$(git describe --tags)
						echo -e ${CYAN}"Checking out the latest tagged version of ${REPO_NAME} (${latesttag}) \n" ${NOCOLOR}
						git checkout -q ${latesttag}
						cd ${SCRIPT_LOCATION}		
											
					else
						echo -e ${CYAN}"█ The git repo '${REPO_NAME}' already exists; checking for updates ..." ${NOCOLOR}
						
						cd ${PLUGINS_DIR}/${REPO_DIR}
						git pull origin master
						
						latesttag=$(git describe --tags)
						echo -e ${CYAN}"Checking out the latest tagged version of ${REPO_NAME} (${latesttag}) \n" ${NOCOLOR}
						git checkout -q ${latesttag}
						cd ${SCRIPT_LOCATION}			
				fi
		    
			done	
			
			# THEMES
			echo -e ${GREEN}"█ Checking theme repos...\n" ${NOCOLOR}
			for REPO_NAME in "${GITHUB_REPOS_THEMES[@]}"			
		    do
				### just the repo (removes owner from path)
				REPO_DIR_PREFIXED=$(echo $REPO_NAME | cut -d "/" -f 2) 
				
				### just the plugin (removes theme- prefix from repo name)
				REPO_DIR=${REPO_DIR_PREFIXED/theme-/}	
				
				if [ ! -d ${THEMES_DIR}/${REPO_DIR} ]
				
					then
						echo -e ${CYAN}"█ Cloning '${REPO_NAME}'..." ${NOCOLOR}
						git clone https://github.com/${REPO_NAME}.git ${THEMES_DIR}/${REPO_DIR}
						cd ${THEMES_DIR}/${REPO_DIR}
						
						latesttag=$(git describe --tags)
						echo -e ${CYAN}"Checking out the latest tagged version of ${REPO_NAME} (${latesttag}) \n" ${NOCOLOR}
						git checkout -q ${latesttag}
						cd ${SCRIPT_LOCATION}		
											
					else
						echo -e ${CYAN}"█ The git repo '${REPO_NAME}' already exists; checking for updates ..." ${NOCOLOR}
						
						cd ${THEMES_DIR}/${REPO_DIR}
						git pull origin master
						
						latesttag=$(git describe --tags)
						echo -e ${CYAN}"Checking out the latest tagged version of ${REPO_NAME} (${latesttag}) \n" ${NOCOLOR}
						git checkout -q ${latesttag}
						cd ${SCRIPT_LOCATION}			
				fi
		    
			done			
				
			for SITE in "$@"
			do
				if test -e ${SITE}/bootstrap.php && grep -q OMEKA_VERSION ${SITE}/bootstrap.php
				    then 	
				    	echo -e ${GREEN}"\n█ Omeka installation found at ${SITE}\n" ${NOCOLOR}
				    	echo -e ${CYAN}"█ Syncing required and optional plugins to ${SITE}/plugins ..." ${NOCOLOR}
				    	rsync -a --stats --exclude='.git/' $PLUGINS_DIR/* ${SITE}/plugins
						
				    	rsync -a --stats --exclude='.git/' $THEMES_DIR/curatescape/curatescape ${SITE}/themes
				    	# (this will need to be updated if there is ever an additional/different theme)
				    	echo -e ${CYAN}"\n█ Syncing recommended themes to ${SITE}/themes ..." ${NOCOLOR}

				    	SUMMARY+="\n${GREEN}${BOLD}✔ ${SITE}:${NORMAL}${NOCOLOR}\n  ➡ Installed the latest theme and plugin versions.\n  ➡ Be sure to log into your site to complete the installation/upgrade\n"${NOCOLOR}

					else
						echo -e ${YELLOW}"\n█ Omeka installation not found at ${SITE}. Skipping this directory.\n" ${NOCOLOR}
						SUMMARY+="\n${YELLOW}${BOLD}✗ ${SITE}:${NORMAL}${NOCOLOR}\n  ➡ Skipped (not an Omeka installation)\n"${NOCOLOR}
				fi
			done
			printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
			echo -e ${CYAN}"\n\n${SUMMARY}\n\n" ${NOCOLOR}
			printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
fi
