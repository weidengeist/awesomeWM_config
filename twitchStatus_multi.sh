#!/bin/bash

dir=$(cd $(dirname "$0") ; pwd)
channels=($(echo "$@" | sed 's|--[^ ]*||g'))

clientID="$(cat "${HOME}/.config/twitch/clientID")"
oauth="$(cat "${HOME}/.config/twitch/oauth")"
apiURL="$(cat "${HOME}/.config/twitch/apiURL")"
imagesDir="${HOME}/.config/twitch/images"

if [[ ! -e "$imagesDir" ]]; then
	mkdir "$imagesDir"
fi
	

curlParameters='-sH "Client-ID: '$clientID'" -H "Authorization: Bearer '$oauth'" -X GET "'$apiURL


contains(){
	[[ "${1/$2/}" == "$1" ]] && bool=1 || bool=0
	return $bool
}


function getChannelsInfo(){
  channelInfoURL="${curlParameters}users?"
  for i in $(seq 0 $((${#channels[@]} - 1))); do
    channelInfoURL="${channelInfoURL}login=${channels[$i]}"
    if [[ $i -lt $((${#channels[@]} - 1)) ]]; then
      channelInfoURL="${channelInfoURL}&"
    fi
  done

  response=""
  trials=0
  while [[ "$response" == "" ]]; do
    response=$(eval curl "$channelInfoURL\"")
    if [[ "$response" == "" ]]; then
      ((trials++))
      sleep 5
    fi
    if [[ $trials == 3 ]]; then
      exit 1
    fi
  done
  IFS=$'\n'
  response=($(echo "$response" | grep -oP "{.*?(?<=})"))
  unset IFS
  echo "${response[@]}"
}


function getStreamsStatus(){
  streamStatusURL="${curlParameters}streams?"
  for i in $(seq 0 $((${#channels[@]} - 1))); do
    streamStatusURL="${streamStatusURL}user_login=${channels[$i]}"
    if [[ $i -lt $((${#channels[@]} - 1)) ]]; then
      streamStatusURL="${streamStatusURL}&"
    fi
  done
  
  response=""
  trials=0
  while [[ "$response" == "" ]]; do
    response=$(eval curl "$streamStatusURL\"")
    if [[ "$response" == "" ]]; then
      ((trials++))
      sleep 5
    fi
    if [[ $trials == 3 ]]; then
      exit 1
    fi
  done
  IFS=$'\n'
  response=($(echo "$response" | grep -oP "{.*?(?<=}[,}])"))
  unset IFS
  echo -e "${response[@]}"
}


function updateProfileImage(){
  user="$1"
  imageURL="$2"
  #url_image=$(echo "$channelInfo" | grep -oP '"profile_image_url":"\K.*?(?=")')
	size_current=$(ls -l $imagesDir/$user.jpg 2>/dev/null | awk '{print $5}')
	size_new=$(curl -sI "$imageURL" | grep -oP '(?<=content-length: )\K[0-9]*')
  echo "size_current: $size_current"
  echo "size_new: $size_new"
	if [[ $size_new != "" ]]; then
    if [[ $size_current != $size_new ]]; then
      echo "New image! Updating from $imageURL."
      echo "Putting it to $imagesDir/$user.jpg"
      curl -s "$imageURL" --output "$imagesDir/$user.jpg"
    fi
  else
    echo "Invalid image URL."
  fi
}

args=$(echo -e "$@")


if contains "$args" "--getChannelsInfo"; then
  getChannelsInfo
fi

if contains "$args" "--getStreamsStatus"; then
  getStreamsStatus
fi

if contains "$args" "--updateProfileImage"; then
  user="$(echo "$args" | sed 's| *--[^ ]* *||g' | sed 's| *http[^ ]* *||g')"
  imgURL="$(echo "$args" | grep -oP 'http[^ ]*\.(jpg|png|jpeg)')"
  echo "user: $user"
  echo "URL: $imgURL"
  if [[ "$user" != "" && "$imgURL" != "" ]]; then
    updateProfileImage "$user" "$imgURL"
  fi
fi
