#!/bin/bash

#
#- openssl_sign:
#	content:
#	algorithm: sha256
#	privatekey: a.pem
#	signed_with: dgst
	

function output(){

	case ${2} in
	false)
		cat <<-!
			{
			"changed": ${1},
			"failed": ${2},
			"sig": "${3}"
			}
!
	;;
	true)
		cat <<-!
			{
			"changed: ${1}",
			"failed": ${2},
			"msg": ${3}
			}
!
	;;
	esac

}

function signature(){

		signed_with=${signed_with:-dgst}
		
		if [[ ${signed_with} == 'dgst' ]]; then

			[[ ! -z ${content} ]] && { 
				[[ -f ${content} ]] && {
					output false true 'This is a file, you must need to use option "path" instead.'		
				} || {

						exec=`echo ${content} | openssl ${signed_with} -${algorithm} -sign ${privatekey} | openssl base64 -e -A` 
						echo ${exec} > err.log
						output true false ${exec}
					}
			} || {

				[[ ! -z ${path} ]] && {

					[[ ! -f ${path} ]] && { 

						output false true 'This is a string, you must need to use option "content" instead.'	

					} || {

						exec=`openssl ${signed_with} -${algorithm} -sign ${privatekey} ${path} | openssl base64 -e -A`
						output true false ${exec}

					}

				} || { output false true 'You must need specified path or content as a source to sign.' ;}; exit 1
			}

		elif [[ ${signed_with} == 'pkeyutl' ]]; then

			[[ ! -z ${content} ]] && {
				[[ -f ${content} ]] && {
		
					output false true 'This is a file, you must need to use option "path" instead.'		

				} || {

					exec=`echo ${content} | openssl ${signed_with} -${algorithm} -sign ${privatekey} | openssl base64 -e -A`
					output true false ${exec}
				}

			} || {
				[[ ! -z ${path} ]] && {
					[[ ! -f ${path} ]] && {
			
						output false true 'This is a string, you must need to use option "content" instead.'	

					} || {

						exec=`openssl ${signed_with} -${algorithm} -sign ${privatekey} ${path} | openssl base64 -e -A`
						output true false ${exec}
					}

				} || { output false true 'You must need specified path or content as a source to sign.' ;}; exit 1
			}
		else
			output false true "Invalid option to sign, options available [ 'dgst', 'pkeyutl'], got: ${signed_with}."; exit 1
		fi
	
}

function __main__(){

	[[ ! -z ${signed_with} || ! -z ${privatekey} ]] && {
		signature
	} || {
		output false true 'You must need to specified the privatekey and signed_with.'; exit 1
	}
	
}

source $1; __main__
