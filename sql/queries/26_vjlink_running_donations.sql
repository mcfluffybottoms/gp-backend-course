-- 26. Нарастающая сумма донатов внутри каждого стрима Вжлинка за 2021 год.
-- Стримы Вжлинка, начавшиеся в 2021 году по UTC, строка на каждый донат; running_total —
-- нарастающая сумма донатов своего стрима по sent_at_sec.
--
-- Колонки: stream_id, title, sent_at_sec, donor, amount, running_total
-- Порядок: stream_id по возрастанию, внутри стрима sent_at_sec по возрастанию
-- Строк:   192

SELECT
    s.stream_id,
    s.title,
    d.sent_at_sec,
    d.nickname AS donor,
    d.amount,
    SUM(d.amount) OVER (
        PARTITION BY s.stream_id
        ORDER BY d.sent_at_sec
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM streams AS s
JOIN streamers AS st
    ON st.streamer_id = s.streamer_id
JOIN stream_donations AS d
    ON d.stream_id = s.stream_id
WHERE st.nickname = 'Вжлинк'
  AND s.started_at >= TIMESTAMPTZ '2021-01-01 00:00:00+00'
  AND s.started_at <  TIMESTAMPTZ '2022-01-01 00:00:00+00'
ORDER BY
    s.stream_id ASC,
    d.sent_at_sec ASC
LIMIT 192;