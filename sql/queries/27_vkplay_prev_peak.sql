-- 27. Пик онлайна против пика предыдущего эфира того же стримера.
-- Только площадка 'VK Play Live'; prev_peak — пик предыдущего по started_at эфира того
-- же стримера, delta — их разность; первый эфир каждого стримера не выводится.
--
-- Колонки: streamer, followers, started_at, title, peak_viewers, prev_peak, delta
-- Порядок: followers по убыванию, внутри стримера started_at по возрастанию
-- Строк:   592

WITH stream_peaks AS (
    SELECT
        s.stream_id,
        s.streamer_id,
        s.started_at,
        s.title,
        s.peak_viewers,
        LAG(s.peak_viewers) OVER (
            PARTITION BY s.streamer_id
            ORDER BY s.started_at, s.stream_id
        ) AS prev_peak
    FROM streams AS s
    JOIN streamers AS st
        ON st.streamer_id = s.streamer_id
    JOIN platforms AS p
        ON p.platform_id = st.platform_id
    WHERE p.name = 'VK Play Live'
)
SELECT
    st.nickname AS streamer,
    st.followers,
    sp.started_at,
    sp.title,
    sp.peak_viewers,
    sp.prev_peak,
    sp.peak_viewers - sp.prev_peak AS delta
FROM stream_peaks AS sp
JOIN streamers AS st
    ON st.streamer_id = sp.streamer_id
WHERE sp.prev_peak IS NOT NULL
ORDER BY
    st.followers DESC,
    sp.started_at ASC;