#!/bin/bash
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
    [z]='--..' [.]='.-.-.-'
)

# Функция для выбора буквы с учётом её вероятности
choose_letter() {
    local total_weight=0
    for time in "${letters[@]}"; do
        ((total_weight += time))
    done
    local rand=$((RANDOM % total_weight))
    local cumulative=0
    for key in "${!letters[@]}"; do
        ((cumulative += letters[$key]))
        if ((rand < cumulative)); then
            echo "$key"
            return
        fi
    done
}

# Функция для воспроизведения буквы в азбуке Морзе.
# -f - частота -l - длительность звучания.
# sleep - время между точками и тире.
play_morse() {
    local letter=$1
    local code=${morse_code[$letter]}
    for ((i=0; i<${#code}; i++)); do
        char=${code:$i:1}
        if [[ "$char" == "." ]]; then
            beep -f 800 -l 50  # Точка
        else
            beep -f 800 -l 150  # Тире
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

