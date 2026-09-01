#!/bin/bash

# Проверка наличия аудио-бенчмарка
if ! command -v play &>/dev/null; then
    echo "Ошибка: команда 'play' не найдена." >&2
    echo "Для работы скрипта установите пакет sox (например: sudo pacman -S sox или sudo apt install sox)." >&2
    exit 1
fi

# Проверка входного файла данных
if [[ ! -f "letters.txt" ]]; then
    echo "Ошибка: файл letters.txt не найден в текущей директории." >&2
    exit 1
fi

# Обязательно нужен файл letters.txt с изучаемыми буквами. Формат буква вмермя в миллисекундах
# например
# m 1000
# k 1000
# n 2000
# u 1500

# Читаем файл и загружаем буквы и их длительности в массивы
declare -A letters
while read -r letter time; do
    letters[$letter]=$time
done < letters.txt

# Определение кода Морзе
declare -A morse_code
morse_code=(
    [a]='.-' [b]='-...' [c]='-.-.' [d]='-..' [e]='.'
    [f]='..-.' [g]='--.' [h]='....' [i]='..' [j]='.---'
    [k]='-.-' [l]='.-..' [m]='--' [n]='-.' [o]='---'
    [p]='.--.' [q]='--.-' [r]='.-.' [s]='...' [t]='-'
    [u]='..-' [v]='...-' [w]='.--' [x]='-..-' [y]='-.--'
    [z]='--..' [0]='-----' [1]='.----' [2]='..---' 
    [3]='...--' [4]='....-' [5]='.....' [6]='-....'
    [7]='--...' [8]='---..' [9]='----.'
)

# Функция для выбора буквы с учётом её вероятности
choose_letter() {
    local total_weight=0
    local -a keys=()
    local key

    # Собираем ключи и считаем сумму весов
    for key in "${!letters[@]}"; do
        keys+=("$key")
        ((total_weight += letters[$key]))
    done

    # Защита от нулевого веса
    ((total_weight == 0)) && { echo "${keys[0]}"; return; }

    # Генерируем достаточно большое случайное число
    # (используем несколько вызовов RANDOM)
    local rand=$(( (RANDOM << 15 | RANDOM) % total_weight ))

    local cumulative=0
    for key in "${keys[@]}"; do
        ((cumulative += letters[$key]))
        if ((rand < cumulative)); then
            echo "$key"
            return
        fi
    done

    # На всякий случай (из-за округления)
    echo "${keys[-1]}"
}

# Требуется пакет: sox (и при необходимости libsox-fmt-pulse / libsox-fmt-alsa)
play_morse() {
    local letter=$1
    local code=${morse_code[$letter]}
    for ((i=0; i<${#code}; i++)); do
        char=${code:$i:1}
        if [[ "$char" == "." ]]; then
            play -q -n synth 0.05 sine 900
        else
            play -q -n synth 0.150 sine 900
        fi
        sleep 0.05
    done
}

# Функция для вывода таблицы перед выходом
print_results() {
    echo 'Результаты:'
    for key in "${!letters[@]}"; do
        echo "$key ${letters[$key]}"
    done
}

# Установка обработчика SIGINT
trap "print_results; exit" SIGINT

# Основной цикл
while true; do
    letter=$(choose_letter)
    duration=${letters[$letter]}
    echo "Введите: $letter (время: ${duration} мс)"

    # Воспроизведение сигнала в морзе
    play_morse "$letter"
    #sleep 0.5

    # Засекаем время ожидания ввода
    start_time=$(date +%s%3N)
    read -n 1 input
    end_time=$(date +%s%3N)
    press_time=$((end_time - start_time))

    if [[ "$input" != "$letter" ]]; then
        echo "Ошибка! Нужно было: $letter"
        ((letters[$letter] += 1000))
        sleep 1
    else
        if ((press_time > duration)); then
            letters[$letter]=$press_time
        elif ((press_time < duration)); then
            letters[$letter]=$press_time
        fi
    fi

done
