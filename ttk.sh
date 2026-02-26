#!/bin/bash
# $> ./balance_ttk.sh    # вывод данных
# $> ./balance_ttk.sh 1  # вывод данных с историей оплаты
# На выбор с файлом cookie.txt curl (get_cookies_file) и без него (get_cookies).
# lk.ttk.ru | Баланс ТТК

trap "echo ' Trapped Ctrl-C'; exit 0" SIGINT

# --- Цвета ---

RED='\033[1;31m'
GREEN='\033[1;32m'
NORM='\033[0m'
MAGENTA='\033[35m'
CYAN='\033[36m'

secret='secret.txt'

if ! [ -f "$secret" ]; then
  echo -e "$RED Отсутствует файл с логином и паролем $NORM" && exit 0
fi

source secret.txt  # содержит LOGIN и PASSWORD
URL="https://lk.ttk.ru"
COOKIE_FILE="cookie.txt"
ATTEMPT=0

# --- Параметры curl ---

COMMON_HEADERS=(
  -s --fail
  -A "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0"
  -H 'Accept: */*'
  -H 'Accept-Language: ru,en-US;q=0.7,en;q=0.3'
  -H 'Accept-Encoding: gzip, deflate, br, zstd'
  -H 'Content-Type: application/json'
  -H "Origin: $URL"
  -H 'Connection: keep-alive'
  -H 'Sec-Fetch-Dest: empty'
  -H 'Sec-Fetch-Mode: cors'
  -H 'Sec-Fetch-Site: same-origin'
  -H 'Sec-GPC: 1'
  -H 'Priority: u=4'
  -H 'Pragma: no-cache'
  -H 'Cache-Control: no-cache'
)

function get_cookies_file() {
  # --- Получаем новые куки и основные данные сессии ---
  # --- С использованием файла curl ---

  responce=$(curl "$URL/api/auth/loginByAccount" \
            -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
            -H "Referer: $URL/auth" "${COMMON_HEADERS[@]}" \
            --data-raw "{\"login\":\"$LOGIN\",\"password\":\"$PASSWORD\",\"remember\":false}" \
            -c "$COOKIE_FILE" | jq '.[]' 2> /dev/null)

  if ! [[ "$responce" ]]; then
    echo "Ошибка получения страницы логина" && exit
  fi

  loginKey=$(awk '/loginKey/ {print $NF}' "$COOKIE_FILE" 2>/dev/null)
  sessionId=$(awk '/sessionId/ {print $NF}' "$COOKIE_FILE" 2>/dev/null)

  merged_json=$(echo "$responce" | jq --arg loginKey "$loginKey" --arg sessionId "$sessionId" \
  '. + {loginKey: $loginKey, sessionId: $sessionId}')

  echo "$merged_json"
}

function get_cookies() {
  # --- Получаем новые куки и основные данные сессии ---
  # --- Без использования файла curl ---

  responce=$(curl -s -D - "$URL/api/auth/loginByAccount" \
          -H "Referer: $URL/auth" "${COMMON_HEADERS[@]}" \
          --data '{"login":"'"$LOGIN"'","password":"'"$PASSWORD"'","remember":false}')

  headers=$(echo "$responce" | sed '/^\r$/q')
  body=$(echo "$responce" | sed '1,/^\r$/d' | jq '.[]' 2> /dev/null)

  if ! [[ "$body" ]]; then
    echo "Ошибка получения страницы логина" && exit
  fi

  loginKey=$(echo "$headers" | grep -i 'Set-Cookie: loginKey=' | sed 's/.*loginKey=\([^;]*\).*/\1/')
  sessionId=$(echo "$headers" | grep -i 'Set-Cookie: sessionId=' | sed 's/.*sessionId=\([^;]*\).*/\1/')
  
  merged_json=$(echo "$body" | jq --arg loginKey "$loginKey" --arg sessionId "$sessionId" \
  '. + {loginKey: $loginKey, sessionId: $sessionId}')

  echo "$merged_json"
}

function session() {
  # raw=$(get_cookies_file)  # С использованием файла curl
  raw=$(get_cookies)  # Без использования файла curl

  loginKey=$(jq -r '.loginKey' 2>/dev/null <<< "$raw")
  sessionId=$(jq -r '.sessionId' 2>/dev/null <<< "$raw")

  if [[ -z "$loginKey" || -z "$sessionId" ]] && [ "$ATTEMPT" -lt 2 ]; then
    echo -e "${GREEN}Не получены ${RED}loginKey, sessionId${NORM}\n"
    ATTEMPT=$(( ATTEMPT + 1 ))
    (( ATTEMPT == 2 )) && exit
    sleep 2
    session "$@"
  fi

  # --- Вывод данных ---

  contract=$(jq -r '.contract' <<< "$raw")
  status=$(jq -r '.status' <<< "$raw")
  contract_id=$(jq -r '.contract_id' <<< "$raw")

  echo "contract: $contract"
  if [ "$status" = 'Активен' ]; then
    echo -e "status: ${GREEN}${status}${NORM}"
  else
    echo -e "status: ${RED}${status}${NORM}"
  fi
  echo "contract_id: $contract_id"

  echo "loginKey: $loginKey"
  echo -e "sessionId: $sessionId\n"

  # --- Первый POST запрос данных в json-формате ---

  info=$(curl "$URL/api/user" \
  -H "Referer: $URL/" "${COMMON_HEADERS[@]}" \
  -H "Cookie: sessionId=${sessionId}; loginKey=${loginKey}" \
  --data-raw "{\"contract_id\":\"${contract_id}\"}" | jq 2> /dev/null)

  # --- Вывод данных ---

  last_name=$(echo "$info" | jq -r '.last_name')
  first_name=$(echo "$info" | jq -r '.first_name')
  middle_name=$(echo "$info" | jq -r '.middle_name')
  echo "name: $last_name $first_name $middle_name"
  address=$(echo "$info" | jq -r '.address')
  echo "address: $address"
  login=$(echo "$info" | jq -r '.login')
  echo "login: $login"
  balance=$(echo "$info" | jq -r '.balance')
  echo -e "balance: ${MAGENTA}${balance}${NORM}\n"

  # --- Второй POST запрос данных в json-формате ---

  tariff_price=$(curl "$URL/api/services/getServices" \
  -H "Referer: $URL/" "${COMMON_HEADERS[@]}" \
  -H "Cookie: sessionId=${sessionId}; loginKey=${loginKey}" \
  --data-raw "{\"contract_id\":\"${contract_id}\"}" | jq -r ".[]" 2> /dev/null)

  # --- Вывод данных ---

  tariff=$(echo $tariff_price | jq -r '.tariff')
  price=$(echo $tariff_price | jq -r '.price')
  echo "tariff: $tariff"
  echo -e "price: ${CYAN}${price}${NORM}"

  # --- Вывод истории оплат ---

  if [[ "$#" -gt 0 ]]; then
    days=$(( 14 * 24 * 60 * 60 ))  # 14 дней * 24 часа * 60 минут * 60 секунд
    now_date=$(date +%Y-%m-%d)  # Текущая дата
    target_date=$(date -d "@$(( $(date +%s) - days ))" +%Y-%m-%d)  # Дата на 2 недели назад

    getHistory=$(curl "$URL/api/payments/getHistory" \
    -H "Referer: $URL/finance" "${COMMON_HEADERS[@]}" \
    -H "Cookie: sessionId=${sessionId}; loginKey=${loginKey}; GEO_CITY_ID=8527; "\
    "GEO_CITY_CODE=komsomolsknaamure; BXMOD_AUTH_LAST_PAGE_Y=%2F" \
    --data-raw "{\"contract_id\":\"${contract_id}\",\"start_date\":\"${target_date}\",\"end_date\":\"${now_date}\"}")

    echo -e "\n${CYAN}История оплаты:${NORM}"

    echo "$getHistory" | jq -c '.[]' | while read -r item; do
      date=$(jq -r '.date' <<< "$item")
      type=$(jq -r '.type' <<< "$item")
      amount=$(jq -r '.amount' <<< "$item")
      name=$(jq -r '.name' <<< "$item")

      # Цвет по знаку суммы
      if [[ $amount == -* ]]; then
        color="${RED}"
      else color="${GREEN}"
      fi

      echo -e "$date | $type | ${color}${amount}${NORM} | $name"  # Печать
    done

  fi
}

session "$@"

