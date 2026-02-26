#!/bin/zsh
# $> ./rostelecom.sh
# lk.rt.ru | Баланс Rostelecom

RED='\033[1;31m'
GREEN='\033[1;32m'
NORM='\033[0m'
MAGENTA='\033[35m'
CYAN='\033[36m'

secret='secret.txt'
if ! [ -f "${secret}" ]; then
  echo -e "${RED} Отсутствует файл с логином и паролем ${NORM}" && exit 0
fi

source secret.txt

request=$(curl -s 'https://api.rt.ru/v2/users/current' \
          -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0' \
          -H "${COOKIE}")

# echo "${COOKIE}" | grep -oP '(lego_token|ELK_CSRF_TOKEN| gsscw-rt-lk|SSO_DEVICE_ID)=[^;]+' | awk -F= '{print $1,":",$2}' 
         
( echo "$request" | grep "Требуется авторизация" &>/dev/null ) && echo " ${RED}Требуется авторизация" && exit

echo "$request" | jq -c | while read -r item; do
  rt_status=$(jq -r '.accounts.[0].status' <<< "$item")
  num_id=$(jq -r '.accounts.[0].id' <<< "$item")
  phone=$(jq -r '.phone' <<< "$item")
  first_name=$(jq -r '.first_name' <<< "$item")
  last_name=$(jq -r '.last_name' <<< "$item")
  middle_name=$(jq -r '.middle_name' <<< "$item")
  client_ids=$(jq -r '.products.[].client_ids.[]' <<< "$item")
done

echo -e "Клиент: ${MAGENTA}${last_name} ${first_name} ${middle_name}${NORM}"
echo -e "Номер телефона: ${CYAN}+${phone}${NORM}"
echo -e "Лицевой счет: ${CYAN}${num_id}${NORM}"
echo -e "Логин: ${CYAN}${client_ids}${NORM}"

if [ "${rt_status}" = 'ACTIVE' ]; then
  echo -e "Статус: ${GREEN}${rt_status}${NORM}"
else
  echo -e "Статус: ${RED}${rt_status}${NORM}"
fi

