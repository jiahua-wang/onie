#!/bin/sh

###########################################################################
# Copyright 2021 Broadcom. The term "Broadcom" refers to Broadcom Inc.    #
# and/or its subsidiaries.                                                #
#                                                                         #
# Licensed under the Apache License, Version 2.0 (the "License");         #
# you may not use this file except in compliance with the License.        #
# You may obtain a copy of the License at                                 #
#                                                                         #
#   http://www.apache.org/licenses/LICENSE-2.0                            #
#                                                                         #
# Unless required by applicable law or agreed to in writing, software     #
# distributed under the License is distributed on an "AS IS" BASIS,       #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.#
# See the License for the specific language governing permissions and     #
# limitations under the License.                                          #
###########################################################################

############################################################
#              Signed ONIE Installer Image                 #
############################################################
###  ONIE Installer Image       (Signature Offset Bytes) ###
############################################################
###  Image Signature            (Signature Len Bytes)    ###
############################################################
###  Image Information Block    (48 Bytes)               ###
############################################################

############################################################
#                Image Information Block                   #
############################################################
###  ONIE Image Identifier GUID (16 Bytes)               ###
############################################################
###  Signature Offset           (16 Bytes)               ###
############################################################
###  Signature Lenth            (16 Bytes)               ###
############################################################

set -e

ONIE_VENDOR_SECRET_KEY_PEM=$1
ONIE_VENDOR_CERT_PEM=$2
FILE=$3
FILE_SIGNED=$4

ONIE_IMAGE_GUID="216e9675-be17-46c7-aa71-e525eac83bd2"
CERT_TYPE_PKCS7_GUID="4aafd29d-68df-49ee-8aa9-347d375665a7"

usage() {
    cat <<EOF
$0: Usage
$0 <ONIE_VENDOR_SECRET_KEY_PEM> <ONIE_VENDOR_SECRET_KEY_PEM> <file> <signed_file>

EOF
}

log() {
    echo $@
}

writebytes2file() {
    local v=$1
    local dest=$2
    echo $v | xxd  -p -r -g0 >> $dest
}

write_guid() {
    for ele in $(echo $1 | tr '-' '\n'); do
        writebytes2file $ele $2
    done
}

write_file_size() {
    local file=$1
    local dest=$2
    signature_size=$(stat --printf="%s" $file)
    writebytes2file $(printf "%016x" $signature_size) $dest
}

generate_signature() {
    local img=$1
    local secret_key=$2
    local cert_file=$3
    local sig=$4

    digest=$img.sha1sum
    sha1sum $img | awk '{ print $1 }' > $digest
    log "Image Digest : $(cat $digest)"
    log "Generating signature for the image digest.."
    openssl cms -sign -signer $cert_file -inkey $secret_key -binary -in $digest -outform der -out $sig -nocerts || {
        rm -f $digest
        log "Error: Failed to create image signature"
        return 1
    }

    # Cleanup intermediate files
    rm -f $digest
}

sign_binary() {
    local img=$1
    local secret_key=$2
    local cert_file=$3
    local signed_img=$4

    [ -z $signed_img ] && signed_img=$img.signed
    iib=$img.iib
    sig=$img.sig
    rm -f $iib $sig

    log "================================================================================"
    log "Signing ONIE installer image $img"
    log "================================================================================"
    # Create image signature file
    generate_signature $img $secret_key $cert_file $sig || {
        return 1
    }

    # Create image information block file
    write_guid $ONIE_IMAGE_GUID $iib
    write_guid $CERT_TYPE_PKCS7_GUID $iib
    write_file_size $img $iib
    write_file_size $sig $iib

    log "Image Information Block:"
    log "ONIE-Image-Id    : $ONIE_IMAGE_GUID"
    log "Signature-Id     : $CERT_TYPE_PKCS7_GUID"
    log "Signature-Offset : $(stat --printf="%s" $img)"
    log "Signature-Length : $(stat --printf="%s" $sig)"

    # Combine image binary, signature and image information block to create a signed binary
    cat $img $sig $iib > $signed_img

    # Cleanup intermediate files
    rm -f $iib $sig

   [ -e $signed_img ] && log "Successfully created signed SONiC image $signed_img"
}

if [ "$#" -ne 4 ]; then
    usage
    exit 1
fi

[ -r $ONIE_VENDOR_SECRET_KEY_PEM ] || {
    echo "Error: ONIE_VENDOR_SECRET_KEY_PEM file does not exist: $ONIE_VENDOR_SECRET_KEY_PEM"
    usage
    exit 1
}

[ -r $ONIE_VENDOR_CERT_PEM ] || {
    echo "Error: ONIE_VENDOR_CERT_PEM file does not exist: $ONIE_VENDOR_CERT_PEM"
    usage
    exit 1
}

[ -r $FILE ] || {
    echo "Error: File for signing does not exist: $FILE"
    usage
    exit 1
}

echo "$0 signing $FILE with ${ONIE_VENDOR_SECRET_KEY_PEM},  ${ONIE_VENDOR_CERT_PEM} to create $FILE_SIGNED"
sign_binary $FILE $ONIE_VENDOR_SECRET_KEY_PEM $ONIE_VENDOR_CERT_PEM $FILE_SIGNED
