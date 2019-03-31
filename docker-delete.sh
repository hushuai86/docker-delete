#!/bin/bash

repositories_dir=$DOCKER_REGISTRY_DIR/docker/registry/v2/repositories

blobs_dir=$DOCKER_REGISTRY_DIR/docker/registry/v2/blobs/sha256/

function deleteBlobs(){
        registryContainerId=`docker ps | grep "registry" |awk '{print $1}'`
        docker exec -it $registryContainerId  sh -c ' registry garbage-collect /etc/docker/registry/config.yml'
	
	emptyPackage=`find $blobs_dir -type d -empty`	

	if [ "$emptyPackage" ]; then
		find $blobs_dir -type d -empty | xargs -n 1 rm -rf
		restartRegistry=`docker restart $registryContainerId`
		if [ $restartRegistry == "$registryContainerId"  ]; then
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

registryContainerNum=`docker ps | grep "registry" |awk 'END{print NR}'`

if [ $registryContainerNum == '0' ]; then
	echo -e "\033[31;1m No registry container is running\033[0m"
	exit 2
fi

if [ $registryContainerNum == '2' ]; then
	echo -e "\033[31;1m Not supported to run two registry containers for the time being\033[0m"
	exit 2
fi

if [ ! -n "$1" ];then 
	showHelp
else

	if [ $1 == '-sr' ]; then
		echo -e "\033[34;1m`ls $repositories_dir`\033[0m"
		exit 0
	fi


	if [ $1 == '-st' ]; then

		if [ ! $2 ]; then
			echo -e "\033[31;1m use ‘docker-delete -st <image repository>' to show all tags of specified repository \033[0m"
			exit 2
		fi

		tags_dir=$repositories_dir/$2/_manifests/tags

		if [ ! -d "$tags_dir" ];then
			echo -e "\033[31;1m no such image repository :  $2  ,please use 'docker-delete -sr' to show all repositories \033[0m"
			exit 2
		fi
	
		echo -e "\033[34;1m`ls $tags_dir`\033[0m"
		exit 0

	fi


	if [ $1 == '-dr' ]; then
	
		if [ ! $2 ]; then
			echo -e "\033[31;1m use ‘docker-delete -dr <image repository>' to delete specified repository or ‘docker-delete -dr -all’ to delele all repositories \033[0m"
			exit 2
		fi
	
		if [ $2 == '-all' ]; then
			rm -rf $repositories_dir/*
			deleteBlobs
		   	echo -e "\033[32;1m Successful deletion of all image repositories \033[0m"
			exit 0
		fi

		repository=$repositories_dir/$2
    
		if [ ! -d "$repository" ]; then
			echo -e "\033[31;1m no such image repository : $2 ,please use 'docker-delete -sr' to show all repositories \033[0m"
			exit 2
		fi
	
		echo `rm -rf $repository`
		deleteBlobs
		echo -e "\033[32;1m Successful deletion of image repository:\033[0m \033[34;1m$2\033[0m"
		exit 0

	fi


	if [ $1 == '-dt' ]; then
	
		if [ ! $2 ]; then
			echo  -e "\033[31;1m use ‘docker-delete -dt <image repository> <images tag>' to delete specified tag of specified repository or ‘docker-delete -dt <image repository>’ to delele all tags of specified repository \033[0m"
			exit 2

		fi
	
		repository=$repositories_dir/$2
    
		if [ ! -d  "$repository" ]; then
			echo -e "\033[31;1m no such image repository :  $2  ,you can use 'docker-delete -sr' to show all repositories \033[0m"
			exit 2
		fi
	
		tags_dir=$repositories_dir/$2/_manifests/tags
		sha256_dir=$repositories_dir/$2/_manifests/revisions/sha256
		if [ ! $3 ]; then
			rm -rf $tags_dir/*
			rm -rf $sha256_dir/*
			deleteBlobs
		   	echo -e "\033[32;1m Successful deletion of all tags under \033[0m \033[34;1m$2\033[0m"
			exit 0
		fi
	
		tag=$tags_dir/$3
	
		if [ ! -d  "$tag" ]; then
			echo -e "\033[31;1m no such image tag : '$3' under $2,you can  use 'docker-delete -st $2' to  show all tags of $2 \033[0m"
			exit 2
		fi

		digest=`ls $tags_dir/$3/index/sha256`
		digestNum=`find $repositories_dir/*/_manifests/tags -type d -name "$digest" | awk 'END{print NR}'`
	
		if [ "$digestNum" == '1' ]; then
			rm -rf $sha256_dir/$digest
		fi

		rm -rf $tag
		deleteBlobs
		echo  -e "\033[32;1m Successful deletion of\033[0m \033[34;1m$2:$3\033[0m"
		exit 0

	fi
	showHelp
fi
