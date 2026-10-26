-- 01. Схема учебной предметной области: соревновательная Dota 2.
--
-- Семнадцать таблиц: справочники патчей и площадок, герои с ролями,
-- игроки, команды и их составы, турниры, матчи с баном и пиком героев,
-- предметы с рекурсивными рецептами, стримеры, стримы и донаты.
--
-- Показаны: первичный и составной первичный ключ, внешний ключ,
-- составной внешний ключ, NOT NULL, UNIQUE, CHECK, ссылочные действия
-- ON DELETE и ON UPDATE, самоссылающееся отношение (item_recipe),
-- связи «один ко многим» и «многие ко многим», необязательная связь
-- «один к одному» (streamers.player_id).
--
-- Файл идемпотентен: повторный запуск пересоздаёт схему целиком.
-- Индексы, кроме порождаемых ограничениями, намеренно не создаются.

-- Часовой пояс фиксируется, иначе приведение timestamptz к date
-- зависит от настроек клиента и данные перестают быть детерминированными.
ALTER DATABASE shop SET timezone = 'UTC';
SET timezone = 'UTC';

DROP TABLE IF EXISTS stream_donations CASCADE;
DROP TABLE IF EXISTS streams CASCADE;
DROP TABLE IF EXISTS streamers CASCADE;
DROP TABLE IF EXISTS match_items CASCADE;
DROP TABLE IF EXISTS item_recipe CASCADE;
DROP TABLE IF EXISTS items CASCADE;
DROP TABLE IF EXISTS match_players CASCADE;
DROP TABLE IF EXISTS match_bans CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS tournaments CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS hero_roles CASCADE;
DROP TABLE IF EXISTS heroes CASCADE;
DROP TABLE IF EXISTS patches CASCADE;
DROP TABLE IF EXISTS platforms CASCADE;

-- ---------------------------------------------------------------------
-- Справочники
-- ---------------------------------------------------------------------

-- Площадки, на которых ведут трансляции стримеры.
CREATE TABLE platforms (
    platform_id integer PRIMARY KEY,
    name        text NOT NULL,
    CONSTRAINT platforms_name_uq  UNIQUE (name),
    CONSTRAINT platforms_name_len CHECK (char_length(name) BETWEEN 2 AND 40)
);

-- Версии игры. Матч играется на том патче, который действовал в его день.
CREATE TABLE patches (
    patch_id    integer PRIMARY KEY,
    version     text NOT NULL,
    released_at date NOT NULL,
    CONSTRAINT patches_version_uq  UNIQUE (version),
    CONSTRAINT patches_version_fmt CHECK (version ~ '^[0-9]+\.[0-9]+[a-z]?$'),
    CONSTRAINT patches_released_rng CHECK (released_at BETWEEN date '2011-01-01'
                                                           AND date '2030-12-31')
);

-- Герои. legs — настоящая колонка из API игры: число ног героя.
-- У большинства их две, у Io и Medusa ноль, у Broodmother восемь.
CREATE TABLE heroes (
    hero_id      integer PRIMARY KEY,
    name         text NOT NULL,
    primary_attr text NOT NULL,
    attack_type  text NOT NULL,
    legs         integer NOT NULL,
    CONSTRAINT heroes_name_uq    UNIQUE (name),
    CONSTRAINT heroes_attr_enum  CHECK (primary_attr IN ('str', 'agi', 'int', 'uni')),
    CONSTRAINT heroes_attack_enum CHECK (attack_type IN ('melee', 'ranged')),
    CONSTRAINT heroes_legs_rng   CHECK (legs BETWEEN 0 AND 8)
);

-- Связь «многие ко многим» героя и роли: составной первичный ключ
-- запрещает повторить одну роль у одного героя дважды.
CREATE TABLE hero_roles (
    hero_id integer NOT NULL
                REFERENCES heroes (hero_id) ON DELETE CASCADE ON UPDATE CASCADE,
    role    text NOT NULL,
    CONSTRAINT hero_roles_pk   PRIMARY KEY (hero_id, role),
    CONSTRAINT hero_roles_enum CHECK (role IN ('carry', 'support', 'mid', 'offlane',
                                               'initiator', 'nuker', 'durable',
                                               'escape', 'pusher'))
);

-- ---------------------------------------------------------------------
-- Игроки и команды
-- ---------------------------------------------------------------------

CREATE TABLE players (
    player_id       integer PRIMARY KEY,
    nickname        text NOT NULL,
    country         text NOT NULL,
    mmr             integer NOT NULL,
    behaviour_score integer NOT NULL,
    registered_at   date NOT NULL,
    CONSTRAINT players_nickname_uq  UNIQUE (nickname),
    CONSTRAINT players_nickname_len CHECK (char_length(nickname) BETWEEN 1 AND 40),
    CONSTRAINT players_country_len  CHECK (char_length(country) BETWEEN 2 AND 40),
    CONSTRAINT players_mmr_rng      CHECK (mmr BETWEEN 0 AND 15000),
    CONSTRAINT players_behaviour_rng CHECK (behaviour_score BETWEEN 0 AND 12000),
    CONSTRAINT players_registered_rng CHECK (registered_at BETWEEN date '2009-01-01'
                                                                AND date '2030-12-31')
);

CREATE TABLE teams (
    team_id    integer PRIMARY KEY,
    name       text NOT NULL,
    tag        text NOT NULL,
    founded_at date NOT NULL,
    CONSTRAINT teams_name_uq   UNIQUE (name),
    CONSTRAINT teams_tag_uq    UNIQUE (tag),
    CONSTRAINT teams_name_len  CHECK (char_length(name) BETWEEN 2 AND 60),
    CONSTRAINT teams_tag_len   CHECK (char_length(tag) BETWEEN 1 AND 12),
    CONSTRAINT teams_founded_rng CHECK (founded_at BETWEEN date '1996-01-01'
                                                        AND date '2030-12-31')
);

-- История составов. Дата входа входит в первичный ключ: игрок может
-- вернуться в ту же команду позже. left_at IS NULL — состоит сейчас.
CREATE TABLE team_members (
    team_id   integer NOT NULL
                  REFERENCES teams (team_id) ON DELETE CASCADE ON UPDATE CASCADE,
    player_id integer NOT NULL
                  REFERENCES players (player_id) ON DELETE CASCADE ON UPDATE CASCADE,
    joined_at date NOT NULL,
    left_at   date,
    CONSTRAINT team_members_pk    PRIMARY KEY (team_id, player_id, joined_at),
    CONSTRAINT team_members_order CHECK (left_at IS NULL OR left_at > joined_at)
);

-- ---------------------------------------------------------------------
-- Турниры и матчи
-- ---------------------------------------------------------------------

CREATE TABLE tournaments (
    tournament_id integer PRIMARY KEY,
    name          text NOT NULL,
    prize_pool    bigint NOT NULL,
    started_at    date NOT NULL,
    patch_id      integer NOT NULL
                      REFERENCES patches (patch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT tournaments_name_uq    UNIQUE (name),
    CONSTRAINT tournaments_prize_pos  CHECK (prize_pool > 0),
    CONSTRAINT tournaments_started_rng CHECK (started_at BETWEEN date '2011-01-01'
                                                              AND date '2030-12-31')
);

-- tournament_id IS NULL — обычная игра вне турнира.
-- ON DELETE SET NULL: удаление турнира не удаляет сыгранные матчи.
CREATE TABLE matches (
    match_id      bigint PRIMARY KEY,
    tournament_id integer
                      REFERENCES tournaments (tournament_id)
                      ON DELETE SET NULL ON UPDATE CASCADE,
    started_at    timestamptz NOT NULL,
    duration_sec  integer NOT NULL,
    winner        text NOT NULL,
    patch_id      integer NOT NULL
                      REFERENCES patches (patch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT matches_winner_enum CHECK (winner IN ('radiant', 'dire')),
    CONSTRAINT matches_duration_rng CHECK (duration_sec BETWEEN 300 AND 10800),
    CONSTRAINT matches_started_rng CHECK (started_at >= timestamptz '2011-01-01 00:00:00+00')
);

-- Фаза запретов. order_no — номер бана в драфте, он же часть ключа.
-- Одного героя нельзя забанить в матче дважды.
CREATE TABLE match_bans (
    match_id bigint NOT NULL
                 REFERENCES matches (match_id) ON DELETE CASCADE ON UPDATE CASCADE,
    hero_id  integer NOT NULL
                 REFERENCES heroes (hero_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    side     text NOT NULL,
    order_no smallint NOT NULL,
    CONSTRAINT match_bans_pk       PRIMARY KEY (match_id, order_no),
    CONSTRAINT match_bans_hero_uq  UNIQUE (match_id, hero_id),
    CONSTRAINT match_bans_side_enum CHECK (side IN ('radiant', 'dire')),
    CONSTRAINT match_bans_order_rng CHECK (order_no BETWEEN 1 AND 24)
);

-- Участие игрока в матче. Слоты 1..5 — radiant, 6..10 — dire,
-- это закреплено проверкой match_players_side_slot.
CREATE TABLE match_players (
    match_id      bigint NOT NULL
                      REFERENCES matches (match_id) ON DELETE CASCADE ON UPDATE CASCADE,
    slot          smallint NOT NULL,
    player_id     integer NOT NULL
                      REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    hero_id       integer NOT NULL
                      REFERENCES heroes (hero_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    side          text NOT NULL,
    kills         integer NOT NULL,
    deaths        integer NOT NULL,
    assists       integer NOT NULL,
    last_hits     integer NOT NULL,
    gpm           integer NOT NULL,
    xpm           integer NOT NULL,
    net_worth     integer NOT NULL,
    courier_kills integer NOT NULL,
    CONSTRAINT match_players_pk        PRIMARY KEY (match_id, slot),
    CONSTRAINT match_players_player_uq UNIQUE (match_id, player_id),
    CONSTRAINT match_players_hero_uq   UNIQUE (match_id, hero_id),
    CONSTRAINT match_players_slot_rng  CHECK (slot BETWEEN 1 AND 10),
    CONSTRAINT match_players_side_enum CHECK (side IN ('radiant', 'dire')),
    CONSTRAINT match_players_side_slot CHECK (
        side = CASE WHEN slot <= 5 THEN 'radiant' ELSE 'dire' END),
    CONSTRAINT match_players_stats_nonneg CHECK (
        kills >= 0 AND deaths >= 0 AND assists >= 0 AND last_hits >= 0
        AND gpm >= 0 AND xpm >= 0 AND net_worth >= 0 AND courier_kills >= 0)
);

-- ---------------------------------------------------------------------
-- Предметы
-- ---------------------------------------------------------------------

-- is_recipe = true у свитков рецептов: они покупаются, но ни из чего
-- не собираются и сами являются компонентом сборки.
CREATE TABLE items (
    item_id   integer PRIMARY KEY,
    name      text NOT NULL,
    cost      integer NOT NULL,
    is_recipe boolean NOT NULL,
    CONSTRAINT items_name_uq  UNIQUE (name),
    CONSTRAINT items_cost_rng CHECK (cost BETWEEN 0 AND 20000),
    CONSTRAINT items_name_len CHECK (char_length(name) BETWEEN 2 AND 60)
);

-- Самоссылающееся отношение «многие ко многим»: из чего собирается
-- предмет. Петля запрещена проверкой, более длинные циклы
-- отсутствуют по построению данных и проверяются рекурсивным запросом.
CREATE TABLE item_recipe (
    item_id      integer NOT NULL
                     REFERENCES items (item_id) ON DELETE CASCADE ON UPDATE CASCADE,
    component_id integer NOT NULL
                     REFERENCES items (item_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity     integer NOT NULL,
    CONSTRAINT item_recipe_pk       PRIMARY KEY (item_id, component_id),
    CONSTRAINT item_recipe_no_self  CHECK (item_id <> component_id),
    CONSTRAINT item_recipe_qty_rng  CHECK (quantity BETWEEN 1 AND 6)
);

-- Покупки в матче. Составной внешний ключ ссылается на участие игрока:
-- предмет нельзя купить в слот, которого в матче не было.
CREATE TABLE match_items (
    match_id      bigint NOT NULL,
    slot          smallint NOT NULL,
    item_id       integer NOT NULL
                      REFERENCES items (item_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    bought_at_sec integer NOT NULL,
    CONSTRAINT match_items_pk PRIMARY KEY (match_id, slot, item_id),
    CONSTRAINT match_items_player_fk FOREIGN KEY (match_id, slot)
        REFERENCES match_players (match_id, slot) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT match_items_time_rng CHECK (bought_at_sec BETWEEN 0 AND 10800)
);

-- ---------------------------------------------------------------------
-- Стримеры
-- ---------------------------------------------------------------------

-- player_id IS NULL — стример, который сам не выступает на
-- профессиональном уровне. Связь необязательная «один к одному»:
-- UNIQUE с NULLS DISTINCT (поведение по умолчанию) разрешает
-- сколько угодно строк с NULL, но не два стримера на одного игрока.
CREATE TABLE streamers (
    streamer_id integer PRIMARY KEY,
    nickname    text NOT NULL,
    platform_id integer NOT NULL
                    REFERENCES platforms (platform_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    player_id   integer
                    REFERENCES players (player_id) ON DELETE SET NULL ON UPDATE CASCADE,
    followers   integer NOT NULL,
    started_at  date NOT NULL,
    CONSTRAINT streamers_nickname_uq UNIQUE (nickname),
    CONSTRAINT streamers_player_uq   UNIQUE (player_id),
    CONSTRAINT streamers_followers_rng CHECK (followers BETWEEN 0 AND 50000000),
    CONSTRAINT streamers_started_rng CHECK (started_at BETWEEN date '2009-01-01'
                                                            AND date '2030-12-31')
);

CREATE TABLE streams (
    stream_id     bigint PRIMARY KEY,
    streamer_id   integer NOT NULL
                      REFERENCES streamers (streamer_id) ON DELETE CASCADE ON UPDATE CASCADE,
    started_at    timestamptz NOT NULL,
    duration_min  integer NOT NULL,
    peak_viewers  integer NOT NULL,
    avg_viewers   integer NOT NULL,
    title         text NOT NULL,
    CONSTRAINT streams_duration_rng CHECK (duration_min BETWEEN 1 AND 1440),
    CONSTRAINT streams_viewers_nonneg CHECK (peak_viewers >= 0 AND avg_viewers >= 0),
    CONSTRAINT streams_viewers_order CHECK (avg_viewers <= peak_viewers),
    CONSTRAINT streams_title_len CHECK (char_length(title) BETWEEN 1 AND 120),
    CONSTRAINT streams_started_rng CHECK (started_at >= timestamptz '2011-01-01 00:00:00+00')
);

CREATE TABLE stream_donations (
    donation_id bigint PRIMARY KEY,
    stream_id   bigint NOT NULL
                    REFERENCES streams (stream_id) ON DELETE CASCADE ON UPDATE CASCADE,
    amount      numeric(10,2) NOT NULL,
    sent_at_sec integer NOT NULL,
    nickname    text NOT NULL,
    CONSTRAINT stream_donations_amount_pos CHECK (amount > 0),
    CONSTRAINT stream_donations_time_rng   CHECK (sent_at_sec BETWEEN 0 AND 86400),
    CONSTRAINT stream_donations_nick_len   CHECK (char_length(nickname) BETWEEN 1 AND 40)
);
