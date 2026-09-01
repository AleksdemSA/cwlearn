#!/bin/bash
# ==============================================================================
# Morse Code Trainer (Hardened & Optimized)
# ==============================================================================

set -euo pipefail

DATA_FILE="letters.txt"
MAX_WEIGHT=15000  # Верхний отсекатель веса (мс) во избежание монополизации

# 1. Проверка окружения
if ! command -v play &>/dev/null; then
    echo "Ошибка: утилита 'play' (sox) не найдена." >&2
    echo "Установите sox (pacman -S sox / apt install sox)." >&2
    exit 1
fi

if [[ ! -f "$DATA_FILE" ]]; then
    echo "Ошибка: файл $DATA_FILE не найден." >&2
    exit 1
fi

# 2. Загрузка данных
declare -A letters
while read -r letter time || [[ -n "$letter" ]]; do
    [[ -z "$letter" || "$letter" =~ ^# ]] && continue
    letters["$letter"]="${time:-1000}"
done < "$DATA_FILE"

if (( ${#letters[@]} == 0 )); then
    echo "Ошибка: файл $DATA_FILE пуст или некорректен." >&2
    exit 1
fi

# 3. Алфавит Морзе
declare -A morse_code=(
    [a]='.-'   [b]='-...' [c]='-.-.' [d]='-..'  [e]='.'
    [f]='..-.' [g]='--.'  [h]='....' [i]='..'   [j]='.---'
    [k]='-.-'  [l]='.-..' [m]='--'   [n]='-.'   [o]='---'
    [p]='.--.' [q]='--.-' [r]='.-.'  [s]='...'  [t]='-'
    [u]='..-'  [v]='...-' [w]='.--'  [x]='-..-' [y]='-.--'
    [z]='--..' [0]='-----' [1]='.----' [2]='..---'
    [3]='...--' [4]='....-' [5]='.....' [6]='-....'
    [7]='--...' [8]='---..' [9]='----.'
)

# 4. Взвешенный выбор с устранением 15-битного лимита $RANDOM и Modulo Bias
choose_letter() {
    local total_weight=0
    local keys=()
    local key

    for key in "${!letters[@]}"; do
        keys+=("$key")
        (( total_weight += letters[$key] ))
    done

    if (( total_weight <= 0 )); then
        echo "${keys[0]}"
        return
    fi

    local rand
    if [[ -r /dev/urandom ]]; then
        local raw
        raw=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
        rand=$(( raw % total_weight ))
    else
        rand=$(( ((RANDOM << 15) | RANDOM) % total_weight ))
    fi

    local cumulative=0
    for key in "${keys[@]}"; do
        (( cumulative += letters[$key] ))
        if (( rand < cumulative )); then
            echo "$key"
            return
        fi
    done
    echo "${keys[-1]}"
}

# 5. Синтез звука
play_morse() {
    local letter=$1
    local code=${morse_code[$letter]:-}
    [[ -z "$code" ]] && return

    for ((i=0; i<${#code}; i++)); do
        local char=${code:$i:1}
        if [[ "$char" == "." ]]; then
            play -q -n synth 0.05 sine 900
        else
            play -q -n synth 0.150 sine 900
        fi
        sleep 0.05
    done
}

# 6. Атомарное сохранение состояния
save_results() {
    echo -e "\n\n[+] Сохранение результатов в $DATA_FILE..."
    local tmp_file="${DATA_FILE}.tmp"
    {
        for key in "${!letters[@]}"; do
            echo "$key ${letters[$key]}"
        done
    } > "$tmp_file" && mv "$tmp_file" "$DATA_FILE"
    echo "[+] Успешно сохранено."
}

trap "save_results; exit 0" SIGINT SIGTERM

# 7. Основной цикл
echo "Тренажер Морзе запущен (KISS architecture)."
echo "Нажмите Ctrl+C для безопасного завершения с сохранением весов."
echo "--------------------------------------------------------"

while true; do
    letter=$(choose_letter)
    duration=${letters[$letter]}

    echo -n "Буква: $letter (вес: ${duration} мс) -> "

    play_morse "$letter"

    # Замер времени через EPOCHREALTIME без порождения subshell процессов
    start_raw="${EPOCHREALTIME//[!0-9]/}"
    read -n 1 -r input || true
    end_raw="${EPOCHREALTIME//[!0-9]/}"
    echo ""

    # Вычисление реакции (перевод мкс в мс + защита от монотонного сдвига)
    press_time=$(( (end_raw - start_raw) / 1000 ))
    (( press_time < 0 )) && press_time=10

    if [[ "$input" != "$letter" ]]; then
        echo "   [!] Ошибка! Нажато '$input', ожидалось '$letter'."
        new_weight=$(( letters[$letter] + 1000 ))
        sleep 1
    else
        echo "   [+] Верно! Реакция: ${press_time} мс."
        # Экспоненциальное сглаживание EMA (70% старого веса + 30% нового замера)
        new_weight=$(( (letters[$letter] * 7 + press_time * 3) / 10 ))
    fi

    # Клиппинг веса в рамках допустимого диапазона [50, MAX_WEIGHT]
    (( new_weight > MAX_WEIGHT )) && new_weight=$MAX_WEIGHT
    (( new_weight < 50 )) && new_weight=50
    letters[$letter]=$new_weight
done
