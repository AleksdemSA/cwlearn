#!/bin/bash
# ==============================================================================
# Morse Code Trainer (Hardened & Optimized)
# ==============================================================================

set -euo pipefail

DATA_FILE="letters.txt"
MAX_WEIGHT=15000  # Верхний отсекатель веса (мс) во избежание монополизации

WPM=12  # Скорость (слова в минуту): 8-12 — обучающая, 15-20 — рабочая

# Расчет таймингов по стандарту PARIS: T_dot (мс) = 1200 / WPM
DOT_MS=$(( 1200 / WPM ))
DASH_MS=$(( DOT_MS * 3 ))
PAUSE_MS=$DOT_MS

# Перевод в секунды для SoX (формат 0.XXX)
DOT_SEC=$(printf "%d.%03d" $(( DOT_MS / 1000 )) $(( DOT_MS % 1000 )))
DASH_SEC=$(printf "%d.%03d" $(( DASH_MS / 1000 )) $(( DASH_MS % 1000 )))
PAUSE_SEC=$(printf "%d.%03d" $(( PAUSE_MS / 1000 )) $(( PAUSE_MS % 1000 )))

# 1. Проверка окружения
if ! command -v play &>/dev/null; then
    echo "Ошибка: утилита 'play' (sox) не найдена." >&2
    echo "Установите sox (pacman -S sox / apt install sox)." >&2
    exit 1
fi

if ! command -v bc &>/dev/null; then
    echo "Ошибка: утилита 'bc' не найдена." >&2
    echo "Установите bc (pacman -S bc / apt install bc)." >&2
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
        echo "${keys[0]:-a}"
        return
    fi

    local rand
    # Bash 5.1+ ($SRANDOM) -> 32-битная энтропия без внешних процессов и \n
    if [[ -v SRANDOM ]]; then
        rand=$(( SRANDOM % total_weight ))
    else
        # Фоллбэк для старых версий Bash (30 бит)
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

# 5. Синтез звука и кэширование в RAM
CACHE_DIR="/tmp/morse_cache_$$"

save_results() {
    echo -e "\n[+] Сохранение результатов в $DATA_FILE..."
    local tmp_file="${DATA_FILE}.tmp"
    {
        for key in "${!letters[@]}"; do
            echo "$key ${letters[$key]}"
        done
    } > "$tmp_file" && mv "$tmp_file" "$DATA_FILE"
    echo "[+] Успешно сохранено."
}

cleanup() {
    # Отключаем ловушки во избежание рекурсивного срабатывания
    trap - EXIT SIGINT SIGTERM
    rm -rf "$CACHE_DIR"
    save_results
}

# Каноничный паттерн сигналов: EXIT вызывает cleanup ровно один раз
trap cleanup EXIT
trap "exit 130" SIGINT
trap "exit 143" SIGTERM

init_audio_cache() {
    mkdir -p "$CACHE_DIR"
    echo -n "[*] Генерация аудиоблоков в RAM... "

    # 1. Базовые примитивы
    sox -q -n "$CACHE_DIR/dot.wav"   synth "$DOT_SEC" sine 900
    sox -q -n "$CACHE_DIR/dash.wav"  synth "$DASH_SEC" sine 900
    sox -q -n "$CACHE_DIR/pause.wav" synth "$PAUSE_SEC" sine 0

    # 2. Склеивание буквенных файлов
    for letter in "${!morse_code[@]}"; do
        local code=${morse_code[$letter]}
        local parts=()

        for ((i=0; i<${#code}; i++)); do
            local char=${code:i:1}
            if [[ "$char" == "." ]]; then
                parts+=("$CACHE_DIR/dot.wav")
            else
                parts+=("$CACHE_DIR/dash.wav")
            fi
            
            if (( i < ${#code}-1 )); then
                parts+=("$CACHE_DIR/pause.wav")
            fi
        done

        sox -q "${parts[@]}" "$CACHE_DIR/${letter}.wav"
    done
    echo "Готово."
}

play_morse() {
    local letter=$1
    if [[ -f "$CACHE_DIR/${letter}.wav" ]]; then
        play -q "$CACHE_DIR/${letter}.wav" &>/dev/null || true
    fi
}

# 6. Инициализация аудио перед запуском цикла
init_audio_cache

# 7. Основной цикл
echo "Тренажер Морзе запущен (KISS architecture)."
echo "Нажмите Ctrl+C для безопасного завершения с сохранением весов."
echo "--------------------------------------------------------"

while true; do
    letter=$(choose_letter)
    duration=${letters[$letter]}

    echo -n "Символ: $letter (вес: ${duration} мс) -> "

    # Сброс буфера stdin перед воспроизведением и замером
    read -t 0.001 -n 10000 _ || true

    # Воспроизведение сигнала
    play_morse "$letter"

    # Замер времени через EPOCHREALTIME без subshell
    start_raw="${EPOCHREALTIME//[!0-9]/}"
    read -n 1 -r input || true
    end_raw="${EPOCHREALTIME//[!0-9]/}"
    echo ""

    # Вычисление реакции
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

    # Клиппинг веса в диапазоне [50, MAX_WEIGHT]
    (( new_weight > MAX_WEIGHT )) && new_weight=$MAX_WEIGHT
    (( new_weight < 50 )) && new_weight=50
    letters[$letter]=$new_weight
done
