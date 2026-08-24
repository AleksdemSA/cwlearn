# cwlearn — Adaptive Bash CW Trainer

[English](#english) | [Русский](#русский)

---

## English

### Description
**`cwlearn`** is a lightweight, zero-dependency CLI trainer for Morse Code (CW) operators written in Bash. 

Unlike traditional static drills, `cwlearn` employs a **latency-weighted adaptive repetition algorithm**:
1. It measures the precise operator response time ($\Delta t$) from the end of tone transmission to keypress.
2. It dynamically adjusts the weight/probability matrix for upcoming characters.
3. Characters causing higher cognitive load (longer recognition latency or errors) are scheduled with higher frequency until recognition becomes instinctual.

### Key Highlights
* **Zero-Dependency / KISS**: Runs natively in POSIX terminal environments using standard utilities (`bash`, `coreutils`, and a audio backend like `aplay` or `sox`).
* **Adaptive Spaced Weighting**: Real-time feedback loop continuously updating character weight distributions.
* **Low Overhead**: Direct TTY input handling for responsive operator feedback.

---

## Русский

### Описание
**`cwlearn`** — минималистичный CLI-тренажёр телеграфа (CW) для радиооператоров, написанный на Bash.

В отличие от классических статических генераторов радиограмм, `cwlearn` использует **адаптивный алгоритм на основе задержки отклика (Latency-Weighted Scheduling)**:
1. Замеряет время реакции оператора ($\Delta t$) от момента завершения передачи символа до нажатия клавиши.
2. Динамически пересчитывает веса вероятностей выпадания символов в выборке.
3. Символы, вызывающие высокий когнитивный барьер (наибольшее время распознавания или ошибки), генерируются чаще, пока прием не доводится до автоматизма.

### Архитектурные особенности
* **Принцип KISS / Минимализм**: Работает напрямую в терминале, без тяжелых фреймворков и лишних зависимостей.
* **Адаптивная обратная связь**: Динамический пересчёт весов символов на основе статистики таймингов.
* **Прозрачность**: Минимальные накладные расходы на I/O и простая интеграция в любые UNIX-окружения.
