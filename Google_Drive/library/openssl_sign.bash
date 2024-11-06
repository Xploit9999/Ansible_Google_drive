#!/bin/bash

# -*- coding: utf-8 -*-
# ---
# module: openssl_sign
# short_description: Sign content or files using OpenSSL.
# description:
#   - This module allows signing a text string or a file using a specified hash algorithm and private key with OpenSSL.
#   - It supports two signing methods, C(dgst) and C(pkeyutl), and outputs the signature in base64 format.
# options:
#   content:
#     description:
#       - A string of text to sign.
#       - Must be provided as plain text and not as a file path.
#     required: false
#     type: str
#   path:
#     description:
#       - The path to a file containing content to sign.
#       - Cannot be used at the same time as I(content).
#     required: false
#     type: str
#   algorithm:
#     description:
#       - The hashing algorithm to use for signing.
#       - Supported algorithms are C(sha1), C(sha224), C(sha256), C(sha384), C(sha512), and C(md5).
#     required: true
#     type: str
#   privatekey:
#     description:
#       - Path to the private key file used for signing.
#     required: true
#     type: str
#   signed_with:
#     description:
#       - The OpenSSL command to use for signing.
#       - Accepts either C(dgst) or C(pkeyutl). Defaults to C(dgst).
#     required: false
#     type: str
#     choices: [ 'dgst', 'pkeyutl' ]
#     default: 'dgst'
# author:
#   - John Freidman (@xploit9999)
# notes:
#   - Either I(content) or I(path) must be provided for signing, but not both.
#   - The module requires OpenSSL to be installed on the target machine.
#   - This module only performs a signing operation and does not change the system state.
# examples:
#   - name: Sign a string with sha256 using dgst
#     openssl_sign:
#       content: "This is my content to sign"
#       algorithm: "sha256"
#       privatekey: "/path/to/private_key.pem"
#
#   - name: Sign a file with sha512 using pkeyutl
#     openssl_sign:
#       path: "/path/to/file_to_sign.txt"
#       algorithm: "sha512"
#       privatekey: "/path/to/private_key.pem"
#       signed_with: "pkeyutl"
#
#   - name: Sign a string with md5 using dgst
#     openssl_sign:
#       content: "Sign this text"
#       algorithm: "md5"
#       privatekey: "/path/to/private_key.pem"

function output() {
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
            "changed": ${1},
            "failed": ${2},
            "msg": "${3}"
        }
!
    ;;
    esac
}

function validate_algorithm() {

    valid_algorithms=("sha1" "sha224" "sha256" "sha384" "sha512" "md5")

    for alg in "${valid_algorithms[@]}"; do
        if [[ ${algorithm} == "${alg}" ]]; then
            return 0
	fi
    done

    return 1
}

function signature() {

    signed_with=${signed_with:-dgst}

    [[ ! -x $(which openssl) ]] && { output false true "You must need to have installed openssl package to run this module."; exit 1 ;}

    [[ -z ${algorithm} ]] && { output false true "Algorithm not specified. Please provide a hashing algorithm (e.g., sha256)."; exit 1 ;}

    [[ ! -f ${privatekey} ]] && { output false true "Private key file ${privatekey} does not exist."; exit 1 ;}

    if ! validate_algorithm; then
        output false true "Invalid algorithm: ${algorithm}. Supported algorithms are: ${valid_algorithms[*]}"; exit 1
    fi

    if [[ ${signed_with} == 'dgst' ]]; then
        if [[ -n ${content} ]]; then
            if [[ -f ${content} ]]; then
                output false true "The 'content' parameter should contain a string, not a file path."
            else
                exec=$(echo -n "${content}" | openssl ${signed_with} -${algorithm} -sign ${privatekey} | openssl base64 -e -A |  tr '+/' '-_' | tr -d '=' 2>/dev/null)

                [[ $? -ne 0 ]] && { output false true "Error signing content with OpenSSL. Please check if algorithm is rigth and exists to use with openssl."; exit 1 ;}
              
                output true false "${exec}"
            fi
        elif [[ -n ${path} ]]; then
            if [[ ! -f ${path} ]]; then
                output false true "The specified file in 'path' does not exist."
            else
                exec=$(openssl ${signed_with} -${algorithm} -sign ${privatekey} ${path} | openssl base64 -e -A 2>/dev/null)
                [[ $? -ne 0 ]] && { output false true "Error signing file with OpenSSL."; exit 1 ;}
                output true false "${exec}"
            fi
        else
            output false true "Specify either 'content' or 'path' to sign."
            exit 1
        fi

    elif [[ ${signed_with} == 'pkeyutl' ]]; then
        if [[ -n ${content} ]]; then
            if [[ -f ${content} ]]; then
                output false true "The 'content' parameter should contain a string, not a file path."
            else
                exec=$(echo -n "${content}" | openssl ${signed_with} -sign ${privatekey} | openssl base64 -e -A 2>/dev/null)
                [[ $? -ne 0 ]] && { output false true "Error signing content with OpenSSL pkeyutl."; exit 1 ;}
                output true false "${exec}"
            fi
        elif [[ -n ${path} ]]; then
            if [[ ! -f ${path} ]]; then
                output false true "The specified file in 'path' does not exist."
            else
                exec=$(openssl ${signed_with} -sign ${privatekey} -in ${path} | openssl base64 -e -A 2>/dev/null)
                [[ $? -ne 0 ]] && { output false true "Error signing file with OpenSSL pkeyutl."; exit 1 ;}
                output true false "${exec}"
            fi
        else
            output false true "Specify either 'content' or 'path' to sign."; exit 1
        fi

    else
        output false true "Invalid signing method. Available options are 'dgst' or 'pkeyutl'. Got: ${signed_with}."; exit 1
    fi
}

function __main__() {

    [[ -z ${signed_with} || -z ${privatekey} ]] && {
        output false true "Parameters 'signed_with' and 'privatekey' are required."; exit 1
    } || {
        signature 
    }
}

source ${1};__main__
