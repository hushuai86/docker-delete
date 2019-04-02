#!/bin/bash

repositories_dir=$DOCKER_REGISTRY_DIR/docker/registry/v2/repositories
blobs_dir=$DOCKER_REGISTRY_DIR/docker/registry/v2/blobs/sha256/

function checkConfiguration(){
   	 pass="true"
	
	if [ ! "$DOCKER_REGISTRY_CONTAINER_ID" ]; then	
		echo -e "\033[31;1m Please set the env variable 'DOCKER_REGISTRY_CONTAINER_ID'.\033[0m"
		pass="false"
	else
		containerNum=`docker ps | awk '{print $1}' | grep "$DOCKER_REGISTRY_CONTAINER_ID" |awk 'END{print NR}'`
		if [ $containerNum == '0' ]; then
			echo -e "\033[31;1m No such running container : '$DOCKER_REGISTRY_CONTAINER_ID'.\033[0m"
			echo -e "\033[31;1m Please check that the env variable 'DOCKER_REGISTRY_CONTAINER_ID' is correct.\033[0m"
			pass="false"
		else
			registryContainerNum=`docker ps | awk '{print $1,$2}' | grep "$DOCKER_REGISTRY_CONTAINER_ID" | grep "registry" |awk 'END{print NR}'`
			if [ $registryContainerNum == '0' ]; then
				echo -e "\033[31;1m The container : '$DOCKER_REGISTRY_CONTAINER_ID' is running ,but it is not a Docker Registry containser.\033[0m"
				echo -e "\033[31;1m Please check that the env variable 'DOCKER_REGISTRY_CONTAINER_ID' is correct.\033[0m"
				pass="false"
			fi
		fi
	fi
	
	if [ ! "$DOCKER_REGISTRY_DIR" ]; then 
		echo -e "\033[31;1m Please set the env variable 'DOCKER_REGISTRY_DIR'.\033[0m"
		pass="false"
	else
		if [ ! -d "$repositories_dir" ]; then 
			echo -e "\033[31;1m '$DOCKER_REGISTRY_DIR' is not a Docker Registry dir.\033[0m"
			echo -e "\033[31;1m Please check that the env variable 'DOCKER_REGISTRY_DIR' is correct.\033[0m"
			pass="false"
		fi
	fi
	
	if [ $pass == "false" ]; then
		exit 2
	fi
}

function deleteBlobs(){
   	docker exec -it $DOCKER_REGISTRY_CONTAINER_ID  sh -c ' registry garbage-collect /etc/docker/registry/config.yml'
	
	emptyPackage=`find $blobs_dir -type d -empty`	

	if [ "$emptyPackage" ]; then
		find $blobs_dir -type d -empty | xargs -n 1 rm -rf
		
		restartRegistry=`docker restart $DOCKER_REGISTRY_CONTAINER_ID`
		if [ $restartRegistry == "$DOCKER_REGISTRY_CONTAINER_ID"  ]; then
			echo -e "\033[32;1m Successful restart of registry container\033[0m"
		fi
	        echo -e "\033[32;1m Successful deletion of blobs\033[0m"
	fi
}

function showHelp(){
    	echo -e "\033[31;1m Usage: \033[0m"
        echo -e "\033[31;1m docker-delete -sr                                   [description: show all image repositories] \033[0m"
        echo -e "\033[31;1m docker-delete -st <image repository>                [description: show all tags of specified image repository] \033[0m"
        echo -e "\033[31;1m docker-delete -dr <image repository>                [description: delete specified image repository ] \033[0m"
        echo -e "\033[31;1m docker-delete -dr -all                              [description: delete all image repositories ]"
        echo -e "\033[31;1m docker-delete -dt <image repository> <image tag>    [description: description: delete specified tag of specified image repository ] \033[0m"
        echo -e "\033[31;1m docker-delete -dt <image repository>                [description: description: delete all tags of specified image repository ] \033[0m"
}

function checkRepositoryExist(){
	repository_dir=$repositories_dir/$1
	if [ ! -d "$repository_dir" ];then
		echo -e "\033[31;1m no such image repository : $1 .\033[0m"
		echo -e "\033[31;1m you can use 'docker-delete -sr' to show all repositories.\033[0m"
		exit 2
	fi
}

function checkTagExist(){
	tag_dir=$repositories_dir/$1/_manifests/tags/$2
	if [ ! -d "$tag_dir" ];then
		echo -e "\033[31;1m no such image tag : '$2' under $1 .\033[0m"
		echo -e "\033[31;1m you can  use 'docker-delete -st $1' to  show all tags of $1 .\033[0m"
		exit 2
	fi
}



checkConfiguration

if [ ! -n "$1" ];then 
	showHelp
else

	if [ $1 == '-sr' ]; then
		cd $repositories_dir
		repositories=`find . -name "_manifests" | cut -b 3-`
		if [ ! "$repositories" ];then 
			echo -e "\033[31;1m No image repository existence.\033[0m"
		fi
		echo -e "\033[34;1m${repositories//\/_manifests/}\033[0m"
		exit 0
	fi


	if [ $1 == '-st' ]; then
		if [ ! $2 ]; then
			echo -e "\033[31;1m use ‘docker-delete -st <image repository>' to show all tags of specified repository.\033[0m"
			exit 2
		fi
		checkRepositoryExist "$2"
		tags=`ls $repositories_dir/$2/_manifests/tags`
		if [ ! "$tags" ]; then 
			echo -e "\033[31;1m No tag under $2 .\033[0m"
		fi
		echo -e "\033[34;1m$tags\033[0m"
		exit 0
	fi


	if [ $1 == '-dr' ]; then
		if [ ! $2 ]; then
			echo -e "\033[31;1m use ‘docker-delete -dr <image repository>' to delete specified repository\033[0m"
			echo -e "\033[31;1m or ‘docker-delete -dr -all’ to delele all repositories.\033[0m"
			exit 2
		fi
		if [ $2 == '-all' ]; then
			rm -rf $repositories_dir/*
			deleteBlobs
		   	echo -e "\033[32;1m Successful deletion of all image repositories.\033[0m"
			exit 0
		fi
		checkRepositoryExist "$2"
	
		rm -rf $repositories_dir/$2

		emptyRepositoriesNum=1

		while [ $emptyRepositoriesNum != "0" ]
		do
			find $repositories_dir -type d -empty | grep -v "_manifests" | grep -v "_layers" | grep -v "_uploads" | xargs -n 1 rm -rf
			emptyRepositoriesNum=`find $repositories_dir -type d -empty | grep -v "_manifests" | grep -v "_layers" | grep -v "_uploads" | awk 'END{print NR}'`
		done

		deleteBlobs
		echo -e "\033[32;1m Successful deletion of image repository:\033[0m \033[34;1m$2.\033[0m"
		exit 0
	fi


	if [ $1 == '-dt' ]; then
	
		if [ ! $2 ]; then
			echo  -e "\033[31;1m use ‘docker-delete -dt <image repository> <images tag>' to delete specified tag of specified repository  \033[0m"
			echo  -e "\033[31;1m or ‘docker-delete -dt <image repository>’ to delele all tags of specified repository.\033[0m"
			exit 2
		fi
	
		checkRepositoryExist "$2"
	
		tags_dir=$repositories_dir/$2/_manifests/tags
		sha256_dir=$repositories_dir/$2/_manifests/revisions/sha256
		if [ ! $3 ]; then
			read -p "do you want to delete all tags of '$2' ? ,please input yes or no : " yes
			if [ $yes == "yes" ];then
				rm -rf $tags_dir/*
				rm -rf $sha256_dir/*
				deleteBlobs
				echo -e "\033[32;1m Successful deletion of all tags under \033[0m \033[34;1m$2\033[0m"
				exit 0
			else
				exit 2
			fi
		fi
	
		checkTagExist "$2" "$3"

		digest=`ls $tags_dir/$3/index/sha256`
		digestNum=`find $repositories_dir/*/_manifests/tags -type d -name "$digest" | awk 'END{print NR}'`
	
		if [ "$digestNum" == '1' ]; then
			rm -rf $sha256_dir/$digest
		fi

		rm -rf $tags_dir/$3

	        tags=`ls $tags_dir`	
		
		if [ ! "$tags" ]; then
			rm -rf $sha256_dir/*	
		fi
			
		deleteBlobs
		echo  -e "\033[32;1m Successful deletion of\033[0m \033[34;1m$2:$3\033[0m"
		exit 0

	fi
	showHelp
fi
