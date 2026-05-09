# METRICS.md

Этот гайд описывает минимальный перенос "метрик + ИМП" в чистый форк `srsRAN_4G`.

Под "ИМП" здесь имеется в виду только файл `scripts/exec/IMP.py`. Всё остальное из `scripts` переносить не нужно.

Гайд написан не как обзор текущего дерева, а как инструкция: какие файлы и зачем менять в чистом `srsRAN_4G`, чтобы:

1. `srsenb` начал писать JSON-метрики в `/tmp/enb_report.json`.
2. В JSON появились поля, которые читает `IMP.py`.
3. `IMP.py` смог работать без дополнительных адаптеров.

## Что в итоге должно получиться

После переноса у вас должна быть такая цепочка:

1. Планировщик MAC собирает расширенные per-UE и global метрики.
2. `metrics_json` сериализует их в JSON.
3. `srsenb` пишет поток JSON-объектов в `/tmp/enb_report.json`.
4. `IMP.py` читает этот файл и строит UI.

`IMP.py` использует следующий контракт JSON:

- `mac.jfi`
- `mac.num_ues`
- `mac.scheduler_runtime_us`
- `mac.nof_prb`
- `mac.prb_util`
- `mac.ue_list[].mac_ue_container.rnti`
- `mac.ue_list[].mac_ue_container.dl_prb`
- `mac.ue_list[].mac_ue_container.dl_throughput`
- `mac.ue_list[].mac_ue_container.dl_bler`
- `mac.ue_list[].mac_ue_container.dl_mcs`
- `mac.ue_list[].mac_ue_container.dl_buffer`
- `mac.ue_list[].mac_ue_container.bsr`
- `mac.ue_list[].mac_ue_container.dl_retx_count`
- `mac.ue_list[].mac_ue_container.dl_aggr_level`
- `cell_list[].cell_container.ue_list[].ue_container.bearer_list[].bearer_container.dl_latency`

Если хотя бы этих полей нет, ИМП либо покажет `N/A`, либо начнёт пропускать UE.

## Что переносить

Переносить нужно только:

- `scripts/exec/IMP.py`
- изменения в `srsenb`

Не нужно переносить:

- остальные файлы из `scripts/exec`
- промежуточные json/log-утилиты
- любые оболочки вокруг запуска, если они не относятся напрямую к `IMP.py`

## Блок 1. Включение JSON-канала в eNB

### 1.1. Поля конфигурации

Файл: `srsenb/hdr/enb.h`

В `general_args_t` должны быть поля:

- `metrics_period_secs`
- `metrics_csv_enable`
- `metrics_csv_filename`
- `report_json_enable`
- `report_json_filename`
- `report_json_asn1_oct`

Минимально для ИМП важны:

- `metrics_period_secs`
- `report_json_enable`
- `report_json_filename`

Без них `srsenb` не сможет периодически сбрасывать JSON, который читает `IMP.py`.

### 1.2. Парсинг конфига

Файл: `srsenb/src/main.cc`

В секции `expert` нужно добавить/проверить параметры:

- `expert.metrics_period_secs`
- `expert.report_json_enable`
- `expert.report_json_filename`
- `expert.report_json_asn1_oct`

Минимальная рабочая конфигурация в `enb.conf`:

```ini
[expert]
metrics_period_secs  = 1
report_json_enable   = true
report_json_filename = /tmp/enb_report.json
report_json_asn1_oct = false
```

### 1.3. Регистрация JSON listener

Файл: `srsenb/src/main.cc`

Нужно:

1. Подключить `metrics_json.h`.
2. Создать `json_sink` с `create_json_formatter()`.
3. Создать `json_channel`.
4. Включить `json_channel` через `report_json_enable`.
5. Создать `metrics_json json_metrics(...)`.
6. Зарегистрировать `json_metrics` в `metricshub`.

Без этого `metrics_json::set_metrics()` никогда не будет вызван.

### 1.4. Пример конфига

Файл: `srsenb/enb.conf.example`

Добавьте или проверьте строки:

```ini
#metrics_period_secs  = 1
#report_json_enable   = true
#report_json_filename = /tmp/enb_report.json
#report_json_asn1_oct = false
```

Это не влияет на рантайм напрямую, но важно для повторяемого переноса в другой форк.

## Блок 2. Источник данных для bearer latency

ИМП берёт `dl_latency` не из `mac.ue_list`, а из `cell_list[].ue_list[].bearer_list[]`.

Чтобы это собрать, нужна связка `RRC -> RLC/PDCP -> metrics_json`.

### 2.1. Расширение RRC metrics

Файл: `srsenb/hdr/stack/rrc/rrc_metrics.h`

В `rrc_ue_metrics_t` нужен контейнер:

```cpp
std::vector<std::pair<uint32_t, uint32_t>> drb_qci_map;
```

Смысл:

- `first` = `lcid` bearer-а
- `second` = `QCI`

`metrics_json` использует это как карту, чтобы пройти по bearer-ам и положить в JSON:

- `bearer_id`
- `qci`
- `dl_total_bytes`
- `ul_total_bytes`
- `dl_latency`
- `ul_latency`
- `dl_buffered_bytes`
- `ul_buffered_bytes`

### 2.2. Заполнение `drb_qci_map`

Файл: `srsenb/src/stack/rrc/rrc_ue.cc`

В `rrc::ue::get_metrics(rrc_ue_metrics_t&)` нужно:

1. Получить список установленных DRB.
2. Получить `erab_list`.
3. Для каждого DRB сопоставить `lc_ch_id` и `qos_params.qci`.
4. Записать пары в `drb_qci_map`.

Если этого не сделать, `bearer_list` в JSON будет пустым, а ИМП потеряет `Avg DL Latency`.

## Блок 3. Расширение MAC metrics под ИМП

Основной контракт ИМП сидит в `mac.ue_list` и `mac`.

### 3.1. Структуры per-UE и global

Файл: `srsenb/hdr/stack/mac/common/mac_metrics.h`

В `mac_ue_metrics_t` должны быть поля, как минимум:

- `dl_prb`
- `ul_prb`
- `bsr`
- `dl_throughput`
- `ul_throughput`
- `dl_latency`
- `dl_bler`
- `ul_bler`
- `dl_mcs`
- `dl_retx_count`
- `dl_retx_flag`
- `dl_aggr_level`
- `dl_alloc_count`
- `expected_bitrate`
- `dl_avg_rate`
- `harq_retx_pending`

В `mac_metrics_t` должны быть поля:

- `jfi`
- `num_ues`
- `scheduler_runtime_us`
- `prb_util`
- `nof_prb`

Для ИМП обязательны:

- `dl_prb`
- `dl_throughput`
- `dl_bler`
- `dl_mcs`
- `dl_buffer`
- `bsr`
- `dl_retx_count`
- `dl_aggr_level`
- `jfi`
- `num_ues`
- `scheduler_runtime_us`
- `nof_prb`
- `prb_util`

Остальные поля можно считать расширением контракта под ваш JSON.

## Блок 4. Где считаются per-UE метрики

### 4.1. Точки хранения и окно throughput

Файл: `srsenb/hdr/stack/mac/sched_ue.h`

В `sched_ue` должны появиться:

- счётчики байтов DL/UL
- окно `DL_METRIC_WINDOW_TTI`
- очередь для окна throughput
- накопитель `dl_bler_window`
- `dl_latency_ms`
- метод `record_dl_sched_result(...)`
- метод `get_dl_window_throughput_bps() const`

Это базовый каркас для вычисления:

- `dl_throughput`
- `dl_bler`
- `dl_retx_count`
- `dl_aggr_level`
- `dl_latency`

### 4.2. Обновление per-UE снимка

Файл: `srsenb/src/stack/mac/sched_ue.cc`

В `sched_ue::metrics_read(mac_ue_metrics_t&)` должны писаться:

- `dl_cqi`
- `ul_snr_offset`
- `dl_cqi_offset`
- `bsr`
- `dl_buffer`
- `expected_bitrate`
- `harq_retx_pending`
- `dl_throughput`
- `dl_latency`
- `dl_bler`
- `dl_alloc_count`

Именно это потом уходит в JSON через `metrics_json`.

### 4.3. Фиксация факта DL-выделения

Файл: `srsenb/src/stack/mac/sched_ue.cc`

В `record_dl_sched_result(...)` должны обновляться:

- `current_tti_dl_bytes`
- `current_tti_dl_prbs`
- `current_tti_dl_retx`
- `current_tti_retx_count`
- `current_tti_dl_aggr`
- `dl_alloc_count_total`
- `sched_metrics.dl_prb`
- `sched_metrics.dl_mcs`
- `sched_metrics.dl_retx_count`
- `sched_metrics.dl_retx_flag`
- `sched_metrics.dl_aggr_level`
- `sched_metrics.dl_alloc_count`
- `sched_metrics.dl_latency`
- окно `dl_bler_window`

Без этой функции ИМП не увидит реальные планировочные метрики, даже если JSON уже включён.

### 4.4. Вызов `record_dl_sched_result(...)`

Файл: `srsenb/src/stack/mac/sched_grid.cc`

После успешного DL grant нужно вызвать:

```cpp
user->record_dl_sched_result(...)
```

Туда должны передаваться:

- `enb_cc_idx`
- `pid`
- `tbs`
- число PRB
- `dl_mcs`
- флаг retransmission
- aggregation level

Это единственная точка, где планировщик знает реальный результат выделения ресурса. Если вызов не перенести, `dl_prb`, `dl_retx_count`, `dl_aggr_level`, `dl_throughput` останутся нулями.

### 4.5. Оценка ожидаемого битрейта

Файл: `srsenb/src/stack/mac/sched_ue.cc`

Нужна функция `get_expected_dl_bitrate(...)`.

Она используется:

- в `sched_ue::metrics_read()` для JSON-метрики `expected_bitrate`
- в PF scheduler для приоритета

Если вы хотите перенести только ИМП, а не ваш исследовательский PF-контракт, можно оставить только ту часть, которая нужна JSON.

## Блок 5. Где считаются global MAC metrics

### 5.1. Поля в scheduler state

Файл: `srsenb/hdr/stack/mac/sched.h`

Нужны поля:

- `last_jfi`
- `last_num_ues`
- `last_scheduler_runtime_us`
- `last_prb_util_tti`

Они нужны как кэш последнего общего снимка для `metrics_read(mac_metrics_t&)`.

### 5.2. Агрегация в `new_tti`

Файл: `srsenb/src/stack/mac/sched.cc`

В `sched::new_tti(...)` нужно считать:

- суммарный runtime всех carrier scheduler
- `last_num_ues`
- `last_jfi`
- `last_prb_util_tti`

`JFI` считается по throughput активных UE.

`scheduler_runtime_us` считается как сумма `get_last_runtime_us()` по всем carrier.

### 5.3. Чтение глобальных метрик

Файл: `srsenb/src/stack/mac/sched.cc`

В `sched::metrics_read(mac_metrics_t&)` нужно положить в итоговую структуру:

- `metrics.jfi`
- `metrics.num_ues`
- `metrics.scheduler_runtime_us`
- `metrics.nof_prb`
- `metrics.prb_util`

Это прямой источник для `mac.{jfi,num_ues,scheduler_runtime_us,nof_prb,prb_util}` в JSON.

### 5.4. Важное замечание по `prb_util`

Файлы:

- `srsenb/hdr/stack/mac/sched_carrier.h`
- `srsenb/src/stack/mac/sched_carrier.cc`
- `srsenb/src/stack/mac/sched.cc`

В текущей реализации видно поле `last_prb_util_tti`, но в `sched_carrier.cc` есть закомментированная строка:

```cpp
/* sched->last_prb_util_tti = last_prb_util_tti; */
```

То есть переносить это "как есть" нельзя вслепую.

Если вам нужен честный `mac.prb_util`, надо явно завершить вычисление:

1. Считать занятые PRB за TTI на carrier.
2. Нормализовать на общее число PRB carrier.
3. Сохранить в `carrier_sched::last_prb_util_tti`.
4. Усреднить по carrier в `sched::new_tti`.

Сейчас `IMP.py` умеет жить и без этого, потому что при наличии `nof_prb` он сам пересчитывает `PRB Util` как сумму `dl_prb` по UE.

Вывод:

- для запуска ИМП `prb_util` желателен, но не критичен
- для корректного JSON-контракта его лучше всё же доделать

## Блок 6. PF-специфичные поля

Если вы хотите перенести именно ваш текущий набор метрик, а не только минимально необходимое для ИМП, надо учесть PF scheduler.

### 6.1. PF scheduler

Файл: `srsenb/src/stack/mac/schedulers/sched_time_pf.cc`

Здесь используются:

- `get_expected_dl_bitrate(...)`
- `get_expected_ul_bitrate(...)`
- `ue_ctxt::dl_avg_rate()`

Смысл:

- `r` = ожидаемая мгновенная скорость
- `R` = усреднённая историческая скорость
- приоритет = `r / R^fairness_coeff`

### 6.2. Что реально уходит в JSON

Файл: `srsenb/src/metrics_json.cc`

В JSON добавлены поля:

- `expected_bitrate`
- `dl_avg_rate`
- `harq_retx_pending`

Но важно:

- `expected_bitrate` заполняется
- `harq_retx_pending` заполняется
- `dl_avg_rate` в текущем коде объявлен и сериализуется, но в `sched_ue::metrics_read()` не выставляется

Если хотите перенос один в один, доведите цепочку `dl_avg_rate` до конца:

1. взять значение из PF history
2. положить его в `mac_ue_metrics_t`
3. сериализовать в JSON

Если ИМП остаётся в текущем виде, это поле ему не нужно.

## Блок 7. JSON-сериализация

### 7.1. Заголовок listener-а

Файл: `srsenb/hdr/metrics_json.h`

Нужен класс `metrics_json`, унаследованный от:

```cpp
srsran::metrics_listener<enb_metrics_t>
```

### 7.2. Реализация JSON

Файл: `srsenb/src/metrics_json.cc`

Это главный файл интеграции под ИМП. В нём нужно:

1. Объявить JSON-метрики для:
   - bearer level
   - UE level
   - MAC UE level
   - MAC global level
   - cell level
2. Реализовать `fill_ue_metrics(...)`
3. Реализовать `fill_mac_metrics(...)`
4. Реализовать `metrics_json::set_metrics(...)`

### 7.3. Что должно попадать в `fill_ue_metrics(...)`

В `ue_container` должны уходить:

- `ue_rnti`
- `dl_cqi`
- `dl_mcs`
- `dl_bitrate`
- `dl_bler`
- `ul_snr`
- `ul_mcs`
- `ul_bitrate`
- `ul_bler`
- `ul_phr`
- `ul_bsr`
- `ul_pusch_rssi`
- `ul_pucch_rssi`
- `ul_pucch_ni`
- `ul_pusch_tpc`
- `ul_pucch_tpc`
- `dl_cqi_offset`
- `ul_snr_offset`
- `bearer_list`

### 7.4. PDCP throughput внутри JSON listener-а

Файл: `srsenb/src/metrics_json.cc`

Текущий код считает `dl_bitrate` и `ul_bitrate` не из MAC, а через накопление `PDCP acked bytes` и `PDCP rx bytes` по bearer-ам.

Для этого используются:

- `m.stack.pdcp.ues[i].bearer[...]`
- `m.stack.rrc.ues[i].drb_qci_map`
- локальные `prev_*_map`

Это отдельный канал метрик, не связанный с ИМП напрямую, но он формирует UE-level `dl_bitrate` и `ul_bitrate`.

Если вам для чистого форка нужны только данные ИМП, этот кусок можно оставить как есть, а можно убрать, если UI его не использует.

### 7.5. Что должно попадать в `fill_mac_metrics(...)`

В `mac_ue_container` должны уходить:

- `rnti`
- `dl_cqi`
- `dl_mcs`
- `ul_mcs`
- `dl_prb`
- `ul_prb`
- `bsr`
- `dl_throughput`
- `ul_throughput`
- `dl_latency`
- `dl_bler`
- `ul_bler`
- `dl_buffer`
- `dl_retx_count`
- `dl_retx_flag`
- `dl_aggr_level`
- `dl_alloc_count`
- `expected_bitrate`
- `dl_avg_rate`
- `harq_retx_pending`

Для ИМП критично оставить хотя бы:

- `rnti`
- `dl_prb`
- `dl_throughput`
- `dl_bler`
- `dl_mcs`
- `dl_buffer`
- `bsr`
- `dl_retx_count`
- `dl_aggr_level`

### 7.6. Что должно попадать в корень `mac`

В `metrics_json::set_metrics(...)` нужно писать:

- `jfi`
- `num_ues`
- `scheduler_runtime_us`
- `prb_util`
- `nof_prb`
- `ue_list`

Это главный блок, который читает `IMP.py`.

## Блок 8. Сборка

Файл: `srsenb/src/CMakeLists.txt`

Проверьте, что `metrics_json.cc` добавлен в `add_executable(srsenb ...)`.

Если в вашем чистом форке этого файла ещё нет, нужно:

1. добавить `metrics_json.cc`
2. добавить `metrics_json.h`
3. подключить их в сборку `srsenb`

## Блок 9. Что именно читает ИМП и откуда это берётся

### Global

- `mac.jfi` <- `sched.cc`
- `mac.num_ues` <- `sched.cc`
- `mac.scheduler_runtime_us` <- `sched.cc`
- `mac.nof_prb` <- `sched.cc`
- `mac.prb_util` <- `sched.cc` / `sched_carrier.cc`

### Per UE

- `dl_prb` <- `sched_ue.cc` через `record_dl_sched_result()`
- `dl_throughput` <- `sched_ue.cc` через окно `DL_METRIC_WINDOW_TTI`
- `dl_bler` <- `sched_ue.cc` через `dl_bler_window`
- `dl_mcs` <- `sched_ue.cc`
- `dl_buffer` <- `sched_ue.cc`
- `bsr` <- `sched_ue.cc`
- `dl_retx_count` <- `sched_ue.cc`
- `dl_aggr_level` <- `sched_ue.cc`
- `dl_latency` bearer-а <- `metrics_json.cc` через `RLC/PDCP + drb_qci_map`

## Блок 10. Минимальный чек-лист переноса

Если переносите в новый форк с нуля, идите в таком порядке:

1. Перенесите `scripts/exec/IMP.py`.
2. Включите JSON-канал в `srsenb` через `enb.h`, `main.cc`, `enb.conf.example`.
3. Добавьте/проверьте `metrics_json.h` и `metrics_json.cc`.
4. Расширьте `rrc_metrics.h` и `rrc_ue.cc`, чтобы появился `drb_qci_map`.
5. Расширьте `mac_metrics.h`.
6. Перенесите изменения в `sched_ue.h` и `sched_ue.cc`.
7. Перенесите вызов `record_dl_sched_result()` в `sched_grid.cc`.
8. Перенесите global метрики в `sched.h` и `sched.cc`.
9. При необходимости доделайте `prb_util` в `sched_carrier.*`.
10. Убедитесь, что `metrics_json.cc` включён в `srsenb/src/CMakeLists.txt`.
11. В `enb.conf` включите `report_json_enable = true`.
12. Запустите `srsenb` и проверьте, что `/tmp/enb_report.json` пополняется объектами `"type": "metrics"`.
13. Запустите `IMP.py`.

## Блок 11. Что можно не переносить, если цель только ИМП

Можно не переносить:

- CSV listener
- любые скрипты кроме `IMP.py`
- поля `expected_bitrate`, `dl_avg_rate`, `harq_retx_pending`, если вы не используете их вне JSON-диагностики
- UE-level `dl_bitrate`/`ul_bitrate` из PDCP, если ИМП на них не опирается

Но нельзя не переносить:

- JSON listener
- global `mac` metrics
- per-UE `mac_ue_container`
- `bearer_list[].dl_latency`, если нужен latency в ИМП

## Блок 12. Практические замечания

### 12.1. `prb_util`

Сейчас ИМП умеет сам восстановить `PRB Util` по `sum(dl_prb) / nof_prb`, поэтому это поле не блокирует запуск.

### 12.2. `dl_avg_rate`

Поле объявлено, но цепочка заполнения неполная. Если нужен перенос "бит в бит", его надо отдельно довести.

### 12.3. Поток JSON

`/tmp/enb_report.json` содержит не один JSON-массив, а поток отдельных JSON-объектов подряд:

- `event`
- `metrics`
- `event`
- `metrics`

`IMP.py` это умеет: у него есть свой `extract_json_blocks()`.

Это значит, что формат файла менять не нужно.

## Минимальный результат

Если хотите самый короткий критерий успеха, он такой:

1. `srsenb` пишет `/tmp/enb_report.json`.
2. В каждом `"type": "metrics"` есть `mac.jfi`, `mac.num_ues`, `mac.scheduler_runtime_us`, `mac.nof_prb`, `mac.ue_list`.
3. В `mac.ue_list[].mac_ue_container` есть `rnti`, `dl_prb`, `dl_throughput`, `dl_bler`, `dl_mcs`, `dl_buffer`, `bsr`, `dl_retx_count`, `dl_aggr_level`.
4. В `cell_list[].cell_container.ue_list[].ue_container.bearer_list[]` есть `dl_latency`.
5. `IMP.py` стартует и обновляет UI без адаптеров.

