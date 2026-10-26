-- 02. Данные учебной предметной области: соревновательная Dota 2.
--
-- ПОЛНАЯ ДЕТЕРМИНИРОВАННОСТЬ. Нигде не вызываются random(), now(),
-- current_date, clock_timestamp и прочие нестабильные функции.
-- Крупные таблицы порождаются generate_series и арифметикой по модулю,
-- справочники заданы явными списками. Повторная заливка в чистый том
-- даёт те же строки до единого значения, поэтому ответы задач
-- не зависят от того, когда стенд поднят.
--
-- Имена героев, предметов, игроков, команд и стримеров взяты из игры
-- и с профессиональной сцены. Все числа — статистика матчей, рейтинги,
-- просмотры, донаты, составы команд — выдуманы и настоящих данных
-- не отражают.
--
-- Мощности: platforms 4, patches 12, heroes 60, hero_roles 140,
-- players 300, teams 24, team_members 160, tournaments 12,
-- matches 2500, match_bans 20000, match_players 25000, items 140,
-- item_recipe ~200, match_items 75000, streamers 40, streams 3000,
-- stream_donations ~30000.

SET timezone = 'UTC';

TRUNCATE stream_donations, streams, streamers, match_items, item_recipe, items,
         match_players, match_bans, matches, tournaments, team_members, teams,
         players, hero_roles, heroes, patches, platforms
         RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- Площадки
-- ---------------------------------------------------------------------

INSERT INTO platforms (platform_id, name) VALUES
    (1, 'Twitch'),
    (2, 'YouTube'),
    (3, 'VK Play Live'),
    (4, 'Kick');

-- ---------------------------------------------------------------------
-- Патчи. Патч матча вычисляется позже как последний, вышедший
-- не позже дня матча, поэтому даты обязаны идти по возрастанию.
-- ---------------------------------------------------------------------

INSERT INTO patches (patch_id, version, released_at) VALUES
    ( 1, '6.84', date '2015-04-30'),
    ( 2, '6.86', date '2015-12-16'),
    ( 3, '7.00', date '2016-12-12'),
    ( 4, '7.07', date '2017-10-31'),
    ( 5, '7.20', date '2018-11-19'),
    ( 6, '7.22', date '2019-05-01'),
    ( 7, '7.23', date '2019-11-26'),
    ( 8, '7.27', date '2020-06-28'),
    ( 9, '7.28', date '2020-12-17'),
    (10, '7.30', date '2021-08-18'),
    (11, '7.32', date '2022-08-23'),
    (12, '7.35', date '2023-12-14');

-- ---------------------------------------------------------------------
-- Герои. legs — настоящее поле из API: у Io, Medusa, Morphling, Lich,
-- Enigma и Death Prophet ног нет вовсе, у Broodmother их восемь.
-- ---------------------------------------------------------------------

INSERT INTO heroes (hero_id, name, primary_attr, attack_type, legs) VALUES
    ( 1, 'Anti-Mage',        'agi', 'melee',  2),
    ( 2, 'Axe',              'str', 'melee',  2),
    ( 3, 'Bane',             'int', 'ranged', 4),
    ( 4, 'Bloodseeker',      'agi', 'melee',  2),
    ( 5, 'Crystal Maiden',   'int', 'ranged', 2),
    ( 6, 'Drow Ranger',      'agi', 'ranged', 2),
    ( 7, 'Earthshaker',      'str', 'melee',  2),
    ( 8, 'Juggernaut',       'agi', 'melee',  2),
    ( 9, 'Mirana',           'uni', 'ranged', 4),
    (10, 'Morphling',        'agi', 'ranged', 0),
    (11, 'Shadow Fiend',     'agi', 'ranged', 2),
    (12, 'Phantom Lancer',   'agi', 'melee',  2),
    (13, 'Puck',             'int', 'ranged', 4),
    (14, 'Pudge',            'str', 'melee',  2),
    (15, 'Razor',            'agi', 'ranged', 2),
    (16, 'Sand King',        'uni', 'melee',  6),
    (17, 'Storm Spirit',     'int', 'ranged', 2),
    (18, 'Sven',             'str', 'melee',  2),
    (19, 'Tiny',             'str', 'melee',  2),
    (20, 'Vengeful Spirit',  'uni', 'ranged', 2),
    (21, 'Windranger',       'uni', 'ranged', 2),
    (22, 'Zeus',             'int', 'ranged', 2),
    (23, 'Kunkka',           'str', 'melee',  2),
    (24, 'Lina',             'int', 'ranged', 2),
    (25, 'Lion',             'int', 'ranged', 2),
    (26, 'Shadow Shaman',    'int', 'ranged', 2),
    (27, 'Slardar',          'str', 'melee',  2),
    (28, 'Tidehunter',       'str', 'melee',  2),
    (29, 'Witch Doctor',     'int', 'ranged', 2),
    (30, 'Lich',             'int', 'ranged', 0),
    (31, 'Riki',             'agi', 'melee',  2),
    (32, 'Enigma',           'uni', 'ranged', 0),
    (33, 'Tinker',           'int', 'ranged', 2),
    (34, 'Sniper',           'agi', 'ranged', 2),
    (35, 'Necrophos',        'int', 'ranged', 2),
    (36, 'Warlock',          'int', 'ranged', 2),
    (37, 'Beastmaster',      'uni', 'melee',  2),
    (38, 'Queen of Pain',    'int', 'ranged', 2),
    (39, 'Venomancer',       'uni', 'ranged', 4),
    (40, 'Faceless Void',    'agi', 'melee',  2),
    (41, 'Wraith King',      'str', 'melee',  2),
    (42, 'Death Prophet',    'int', 'ranged', 0),
    (43, 'Phantom Assassin', 'agi', 'melee',  2),
    (44, 'Pugna',            'int', 'ranged', 2),
    (45, 'Templar Assassin', 'agi', 'ranged', 2),
    (46, 'Viper',            'agi', 'ranged', 4),
    (47, 'Luna',             'agi', 'ranged', 4),
    (48, 'Dragon Knight',    'str', 'melee',  2),
    (49, 'Dazzle',           'int', 'ranged', 2),
    (50, 'Clockwerk',        'uni', 'melee',  2),
    (51, 'Leshrac',          'int', 'ranged', 4),
    (52, 'Nature''s Prophet','int', 'ranged', 2),
    (53, 'Lifestealer',      'str', 'melee',  2),
    (54, 'Dark Seer',        'uni', 'melee',  4),
    (55, 'Clinkz',           'agi', 'ranged', 2),
    (56, 'Broodmother',      'uni', 'melee',  8),
    (57, 'Invoker',          'int', 'ranged', 2),
    (58, 'Techies',          'uni', 'ranged', 6),
    (59, 'Io',               'uni', 'ranged', 0),
    (60, 'Medusa',           'agi', 'ranged', 0);

-- ---------------------------------------------------------------------
-- Роли героев: 140 строк, по две-три на героя.
-- ---------------------------------------------------------------------

INSERT INTO hero_roles (hero_id, role)
SELECT h.hero_id, v.role
FROM (VALUES
    ('Anti-Mage', 'carry'),        ('Anti-Mage', 'escape'),
    ('Axe', 'offlane'),            ('Axe', 'initiator'),       ('Axe', 'durable'),
    ('Bane', 'support'),           ('Bane', 'nuker'),
    ('Bloodseeker', 'carry'),      ('Bloodseeker', 'nuker'),
    ('Crystal Maiden', 'support'), ('Crystal Maiden', 'nuker'),
    ('Drow Ranger', 'carry'),      ('Drow Ranger', 'pusher'),
    ('Earthshaker', 'support'),    ('Earthshaker', 'initiator'), ('Earthshaker', 'nuker'),
    ('Juggernaut', 'carry'),       ('Juggernaut', 'pusher'),
    ('Mirana', 'support'),         ('Mirana', 'escape'),       ('Mirana', 'nuker'),
    ('Morphling', 'carry'),        ('Morphling', 'escape'),
    ('Shadow Fiend', 'mid'),       ('Shadow Fiend', 'nuker'),
    ('Phantom Lancer', 'carry'),   ('Phantom Lancer', 'escape'),
    ('Puck', 'mid'),               ('Puck', 'initiator'),      ('Puck', 'escape'),
    ('Pudge', 'offlane'),          ('Pudge', 'durable'),
    ('Razor', 'carry'),            ('Razor', 'durable'),
    ('Sand King', 'initiator'),    ('Sand King', 'nuker'),     ('Sand King', 'escape'),
    ('Storm Spirit', 'mid'),       ('Storm Spirit', 'escape'),
    ('Sven', 'carry'),             ('Sven', 'durable'),
    ('Tiny', 'carry'),             ('Tiny', 'nuker'),
    ('Vengeful Spirit', 'support'),('Vengeful Spirit', 'initiator'),
    ('Windranger', 'support'),     ('Windranger', 'carry'),    ('Windranger', 'nuker'),
    ('Zeus', 'mid'),               ('Zeus', 'nuker'),
    ('Kunkka', 'offlane'),         ('Kunkka', 'initiator'),    ('Kunkka', 'durable'),
    ('Lina', 'mid'),               ('Lina', 'nuker'),
    ('Lion', 'support'),           ('Lion', 'nuker'),
    ('Shadow Shaman', 'support'),  ('Shadow Shaman', 'pusher'),
    ('Slardar', 'offlane'),        ('Slardar', 'durable'),     ('Slardar', 'initiator'),
    ('Tidehunter', 'offlane'),     ('Tidehunter', 'initiator'),('Tidehunter', 'durable'),
    ('Witch Doctor', 'support'),   ('Witch Doctor', 'nuker'),
    ('Lich', 'support'),           ('Lich', 'nuker'),
    ('Riki', 'carry'),             ('Riki', 'escape'),
    ('Enigma', 'offlane'),         ('Enigma', 'initiator'),    ('Enigma', 'pusher'),
    ('Tinker', 'mid'),             ('Tinker', 'pusher'),
    ('Sniper', 'carry'),           ('Sniper', 'nuker'),
    ('Necrophos', 'mid'),          ('Necrophos', 'durable'),
    ('Warlock', 'support'),        ('Warlock', 'pusher'),
    ('Beastmaster', 'offlane'),    ('Beastmaster', 'initiator'),('Beastmaster', 'pusher'),
    ('Queen of Pain', 'mid'),      ('Queen of Pain', 'escape'),
    ('Venomancer', 'support'),     ('Venomancer', 'nuker'),    ('Venomancer', 'pusher'),
    ('Faceless Void', 'carry'),    ('Faceless Void', 'initiator'),('Faceless Void', 'durable'),
    ('Wraith King', 'carry'),      ('Wraith King', 'durable'),
    ('Death Prophet', 'mid'),      ('Death Prophet', 'pusher'),
    ('Phantom Assassin', 'carry'), ('Phantom Assassin', 'escape'),
    ('Pugna', 'mid'),              ('Pugna', 'nuker'),         ('Pugna', 'pusher'),
    ('Templar Assassin', 'carry'), ('Templar Assassin', 'mid'),
    ('Viper', 'offlane'),          ('Viper', 'durable'),       ('Viper', 'nuker'),
    ('Luna', 'carry'),             ('Luna', 'pusher'),
    ('Dragon Knight', 'mid'),      ('Dragon Knight', 'durable'),('Dragon Knight', 'pusher'),
    ('Dazzle', 'support'),         ('Dazzle', 'nuker'),
    ('Clockwerk', 'offlane'),      ('Clockwerk', 'initiator'), ('Clockwerk', 'durable'),
    ('Leshrac', 'mid'),            ('Leshrac', 'nuker'),       ('Leshrac', 'pusher'),
    ('Nature''s Prophet', 'carry'),('Nature''s Prophet', 'pusher'),('Nature''s Prophet', 'escape'),
    ('Lifestealer', 'carry'),      ('Lifestealer', 'durable'),
    ('Dark Seer', 'offlane'),      ('Dark Seer', 'initiator'),
    ('Clinkz', 'carry'),           ('Clinkz', 'escape'),
    ('Broodmother', 'carry'),      ('Broodmother', 'pusher'),
    ('Invoker', 'mid'),            ('Invoker', 'nuker'),       ('Invoker', 'escape'),
    ('Techies', 'support'),        ('Techies', 'nuker'),
    ('Io', 'support'),             ('Io', 'escape'),
    ('Medusa', 'carry'),           ('Medusa', 'durable')
) AS v(hero, role)
JOIN heroes AS h ON h.name = v.hero;

-- ---------------------------------------------------------------------
-- Игроки. Первые 60 — узнаваемые ники профессиональной сцены,
-- остальные 240 порождаются парой «приставка + основа»: двадцать
-- приставок на двенадцать основ дают ровно 240 различных ников.
-- ---------------------------------------------------------------------

INSERT INTO players (player_id, nickname, country, mmr, behaviour_score, registered_at)
SELECT
    v.player_id,
    v.nickname,
    v.country,
    -- Профессионалы: 8000..11999, формула детерминирована номером игрока.
    8000 + (v.player_id * 173) % 4000,
    -- У каждого двадцатого порядочность просела: материал для задач
    -- «кто рискует попасть в low priority».
    CASE WHEN v.player_id % 20 = 0 THEN 1200 + (v.player_id * 53) % 1800
         ELSE 7000 + (v.player_id * 977) % 5000 END,
    date '2011-01-01' + ((v.player_id * 53) % 1500)
FROM (VALUES
    ( 1, 'Dendi',          'Ukraine'),
    ( 2, 'Puppey',         'Estonia'),
    ( 3, 'Miracle-',       'Jordan'),
    ( 4, 'N0tail',         'Denmark'),
    ( 5, 'Topson',         'Finland'),
    ( 6, 'ana',            'Australia'),
    ( 7, 'Collapse',       'Russia'),
    ( 8, 'Yatoro',         'Ukraine'),
    ( 9, 'TORONTOTOKYO',   'Russia'),
    (10, 'Mira',           'Russia'),
    (11, 'RAMZES666',      'Russia'),
    (12, 'No[o]ne',        'Ukraine'),
    (13, 'Solo',           'Russia'),
    (14, 's4',             'Sweden'),
    (15, 'Ceb',            'France'),
    (16, 'JerAx',          'Finland'),
    (17, 'SumaiL',         'Pakistan'),
    (18, 'Arteezy',        'Canada'),
    (19, 'Dread',          'Russia'),
    (20, 'NS',             'Russia'),
    (21, 'SingSing',       'Netherlands'),
    (22, 'AdmiralBulldog', 'Sweden'),
    (23, 'Fear',           'United States'),
    (24, 'UNiVeRsE',       'United States'),
    (25, 'PPD',            'United States'),
    (26, 'Aui_2000',       'Canada'),
    (27, 'BurNIng',        'China'),
    (28, 'Sccc',           'China'),
    (29, 'Maybe',          'China'),
    (30, 'Ame',            'China'),
    (31, 'NothingToSay',   'Malaysia'),
    (32, 'XinQ',           'China'),
    (33, 'Somnus',         'China'),
    (34, 'Faith_bian',     'China'),
    (35, 'Chalice',        'China'),
    (36, 'fy',             'China'),
    (37, 'Kuroky',         'Germany'),
    (38, 'MinD_ContRoL',   'Bulgaria'),
    (39, 'GH',             'Georgia'),
    (40, 'w33',            'Romania'),
    (41, 'Matumbaman',     'Finland'),
    (42, 'Boxi',           'Sweden'),
    (43, 'Taiga',          'Netherlands'),
    (44, 'iNSaNiA',        'Sweden'),
    (45, 'zai',            'United States'),
    (46, 'Cr1t-',          'Denmark'),
    (47, 'Saksa',          'Estonia'),
    (48, 'Nisha',          'Poland'),
    (49, 'YapzOr',         'Jordan'),
    (50, 'Crystallis',     'Bulgaria'),
    (51, 'Larl',           'Russia'),
    (52, 'Rodjer',         'Russia'),
    (53, 'gpk',            'Russia'),
    (54, 'Pure',           'Russia'),
    (55, 'Save-',          'Russia'),
    (56, '9pasha',         'Russia'),
    (57, 'Resolut1on',     'Ukraine'),
    (58, 'Lil',            'Ukraine'),
    (59, 'ALOHADANCE',     'Russia'),
    (60, 'Miposhka',       'Russia')
) AS v(player_id, nickname, country);

INSERT INTO players (player_id, nickname, country, mmr, behaviour_score, registered_at)
SELECT
    60 + g,
    (ARRAY['Dark', 'Blink', 'Ghost', 'Storm', 'Iron', 'Night', 'Rapier', 'Smoke',
           'Frost', 'Crimson', 'Silent', 'Wild', 'Lone', 'Mad', 'Swift', 'Grim',
           'Neon', 'Rune', 'Shade', 'Astral'])[1 + (g - 1) % 20]
    || (ARRAY['Wolf', 'Fang', 'Cat', 'Mage', 'Lancer', 'Ward', 'Creep', 'Shaman',
              'Rider', 'Blade', 'Hawk', 'Spirit'])[1 + (g - 1) / 20],
    (ARRAY['Russia', 'Ukraine', 'Kazakhstan', 'Belarus', 'Sweden', 'Finland',
           'Denmark', 'Germany', 'Poland', 'Romania', 'Bulgaria', 'Estonia',
           'China', 'Malaysia', 'Philippines', 'Peru', 'Brazil', 'Argentina',
           'United States', 'Canada'])[1 + (g * 7) % 20],
    1500 + (g * 311) % 7000,
    CASE WHEN g % 17 = 0 THEN 800 + (g * 37) % 2200
         ELSE 5000 + (g * 613) % 7000 END,
    date '2012-06-01' + ((g * 97) % 4000)
FROM generate_series(1, 240) AS g;

-- ---------------------------------------------------------------------
-- Команды
-- ---------------------------------------------------------------------

INSERT INTO teams (team_id, name, tag, founded_at) VALUES
    ( 1, 'Natus Vincere',     'Na''Vi',  date '2009-12-17'),
    ( 2, 'OG',                'OG',      date '2015-10-01'),
    ( 3, 'Team Spirit',       'TS',      date '2015-01-14'),
    ( 4, 'Virtus.pro',        'VP',      date '2003-06-01'),
    ( 5, 'PSG.LGD',           'LGD',     date '2009-09-01'),
    ( 6, 'Team Secret',       'Secret',  date '2014-08-15'),
    ( 7, 'Evil Geniuses',     'EG',      date '1999-01-01'),
    ( 8, 'Team Liquid',       'Liquid',  date '2000-12-02'),
    ( 9, 'Alliance',          'Alliance',date '2013-02-01'),
    (10, 'Fnatic',            'Fnatic',  date '2004-07-23'),
    (11, 'Newbee',            'Newbee',  date '2014-02-01'),
    (12, 'Wings Gaming',      'Wings',   date '2015-08-01'),
    (13, 'Invictus Gaming',   'iG',      date '2011-08-02'),
    (14, 'Vici Gaming',       'VG',      date '2012-09-01'),
    (15, 'Team Aster',        'Aster',   date '2019-01-10'),
    (16, 'Gaimin Gladiators', 'GG',      date '2021-07-01'),
    (17, 'Tundra Esports',    'Tundra',  date '2019-11-01'),
    (18, 'BetBoom Team',      'BB',      date '2021-05-01'),
    (19, '9Pandas',           '9P',      date '2022-01-20'),
    (20, 'Entity',            'Entity',  date '2021-09-01'),
    (21, 'Nigma Galaxy',      'Nigma',   date '2019-10-01'),
    (22, 'Xtreme Gaming',     'XG',      date '2015-04-01'),
    (23, 'Azure Ray',         'AR',      date '2023-01-05'),
    (24, 'Talon Esports',     'Talon',   date '2017-01-01');

-- ---------------------------------------------------------------------
-- Составы. Явный блок для узнаваемых игроков: именно по нему решается
-- задача «кто из стримеров за какую команду выступает сейчас».
-- left_at IS NULL — состоит в команде на момент среза данных.
-- ---------------------------------------------------------------------

INSERT INTO team_members (team_id, player_id, joined_at, left_at)
SELECT t.team_id, p.player_id, v.joined_at, v.left_at
FROM (VALUES
    ('Natus Vincere',     'Dendi',          date '2010-10-01', NULL::date),
    ('Natus Vincere',     'Resolut1on',     date '2016-06-01', date '2017-09-01'),
    ('Natus Vincere',     'Resolut1on',     date '2022-01-15', NULL),
    ('Natus Vincere',     'Pure',           date '2020-08-01', NULL),
    ('Natus Vincere',     'Rodjer',         date '2021-02-01', NULL),
    ('Natus Vincere',     '9pasha',         date '2019-01-10', date '2021-06-01'),
    ('OG',                'N0tail',         date '2015-11-01', NULL),
    ('OG',                'Ceb',            date '2016-01-20', NULL),
    ('OG',                'Topson',         date '2018-05-01', date '2022-01-10'),
    ('OG',                'ana',            date '2018-05-01', date '2019-11-01'),
    ('OG',                'JerAx',          date '2016-09-01', date '2020-01-01'),
    ('OG',                'Taiga',          date '2022-02-01', NULL),
    ('Team Spirit',       'Yatoro',         date '2020-05-01', NULL),
    ('Team Spirit',       'Collapse',       date '2020-10-01', NULL),
    ('Team Spirit',       'Mira',           date '2021-01-11', NULL),
    ('Team Spirit',       'Miposhka',       date '2020-10-01', NULL),
    ('Team Spirit',       'TORONTOTOKYO',   date '2020-10-01', date '2023-01-15'),
    ('Team Spirit',       'Larl',           date '2023-01-15', NULL),
    ('Virtus.pro',        'RAMZES666',      date '2016-10-01', date '2019-09-01'),
    ('Virtus.pro',        'RAMZES666',      date '2022-01-20', NULL),
    ('Virtus.pro',        'No[o]ne',        date '2016-10-01', date '2020-09-01'),
    ('Virtus.pro',        'No[o]ne',        date '2022-01-20', NULL),
    ('Virtus.pro',        'Solo',           date '2015-11-01', date '2020-09-01'),
    ('Virtus.pro',        'Solo',           date '2021-01-11', NULL),
    ('Virtus.pro',        '9pasha',         date '2016-10-01', date '2019-01-10'),
    ('Virtus.pro',        'NS',             date '2012-01-01', date '2014-01-01'),
    ('PSG.LGD',           'Ame',            date '2017-09-01', date '2022-12-01'),
    ('PSG.LGD',           'Somnus',         date '2016-01-05', date '2022-09-01'),
    ('PSG.LGD',           'Faith_bian',     date '2016-09-01', date '2022-09-01'),
    ('PSG.LGD',           'XinQ',           date '2019-09-01', date '2022-12-01'),
    ('PSG.LGD',           'NothingToSay',   date '2020-09-01', NULL),
    ('PSG.LGD',           'fy',             date '2018-09-01', date '2022-09-01'),
    ('Team Secret',       'Puppey',         date '2014-08-15', NULL),
    ('Team Secret',       'Nisha',          date '2019-01-10', date '2023-11-01'),
    ('Team Secret',       'YapzOr',         date '2017-09-01', date '2022-02-01'),
    ('Team Secret',       'zai',            date '2019-01-10', date '2021-01-20'),
    ('Team Secret',       'Crystallis',     date '2022-11-01', NULL),
    ('Team Secret',       'Saksa',          date '2021-01-20', date '2022-01-15'),
    ('Team Secret',       'MinD_ContRoL',   date '2021-01-20', date '2022-09-01'),
    ('Team Secret',       'Resolut1on',     date '2017-09-01', date '2018-05-01'),
    ('Team Secret',       'SingSing',       date '2015-01-10', date '2015-12-01'),
    ('Evil Geniuses',     'SumaiL',         date '2015-01-15', date '2019-09-01'),
    ('Evil Geniuses',     'Arteezy',        date '2015-09-01', date '2022-09-01'),
    ('Evil Geniuses',     'Arteezy',        date '2023-09-01', NULL),
    ('Evil Geniuses',     'UNiVeRsE',       date '2014-06-01', date '2018-09-01'),
    ('Evil Geniuses',     'Fear',           date '2013-01-01', date '2018-01-01'),
    ('Evil Geniuses',     'PPD',            date '2013-01-01', date '2016-08-01'),
    ('Evil Geniuses',     'Cr1t-',          date '2016-09-01', date '2022-09-01'),
    ('Evil Geniuses',     'Aui_2000',       date '2015-07-01', date '2015-11-01'),
    ('Team Liquid',       'Kuroky',         date '2015-12-01', date '2019-09-01'),
    ('Team Liquid',       'Matumbaman',     date '2015-12-01', date '2019-09-01'),
    ('Team Liquid',       'MinD_ContRoL',   date '2015-12-01', date '2021-01-20'),
    ('Team Liquid',       'GH',             date '2016-09-01', date '2019-09-01'),
    ('Team Liquid',       'Miracle-',       date '2015-12-01', date '2019-09-01'),
    ('Team Liquid',       'Boxi',           date '2021-01-20', NULL),
    ('Team Liquid',       'iNSaNiA',        date '2021-01-20', NULL),
    ('Team Liquid',       'Nisha',          date '2023-11-01', NULL),
    ('Team Liquid',       'zai',            date '2023-01-10', NULL),
    ('Alliance',          's4',             date '2012-07-01', date '2014-12-01'),
    ('Alliance',          'AdmiralBulldog', date '2012-07-01', date '2015-06-01'),
    ('Alliance',          'AdmiralBulldog', date '2023-06-01', NULL),
    ('Alliance',          'Taiga',          date '2019-01-10', date '2021-12-01'),
    ('Alliance',          'Boxi',           date '2019-01-10', date '2020-12-01'),
    ('Fnatic',            'SingSing',       date '2013-01-10', date '2015-01-10'),
    ('Fnatic',            's4',             date '2015-01-10', date '2015-09-01'),
    ('Newbee',            'Sccc',           date '2017-01-10', date '2020-05-01'),
    ('Newbee',            'BurNIng',        date '2015-01-10', date '2016-09-01'),
    ('Invictus Gaming',   'BurNIng',        date '2010-01-10', date '2014-09-01'),
    ('Invictus Gaming',   'Chalice',        date '2021-01-10', NULL),
    ('Vici Gaming',       'Maybe',          date '2014-09-01', date '2016-09-01'),
    ('Team Aster',        'Sccc',           date '2020-06-01', NULL),
    ('Team Aster',        'Maybe',          date '2021-01-10', NULL),
    ('Tundra Esports',    'SingSing',       date '2022-01-10', NULL),
    ('Tundra Esports',    'Saksa',          date '2022-02-01', NULL),
    ('BetBoom Team',      'Dread',          date '2022-01-10', NULL),
    ('BetBoom Team',      'gpk',            date '2023-10-01', NULL),
    ('BetBoom Team',      'Save-',          date '2022-01-10', NULL),
    ('BetBoom Team',      'Larl',           date '2021-09-01', date '2022-12-01'),
    ('BetBoom Team',      '9pasha',         date '2022-01-10', NULL),
    ('9Pandas',           'ALOHADANCE',     date '2022-03-01', NULL),
    ('9Pandas',           'Lil',            date '2022-03-01', NULL),
    ('9Pandas',           'NS',             date '2022-03-01', NULL),
    ('Nigma Galaxy',      'Kuroky',         date '2019-09-01', NULL),
    ('Nigma Galaxy',      'Miracle-',       date '2019-09-01', NULL),
    ('Nigma Galaxy',      'GH',             date '2019-09-01', NULL),
    ('Nigma Galaxy',      'w33',            date '2019-09-01', date '2022-01-15'),
    ('Nigma Galaxy',      'MinD_ContRoL',   date '2022-09-01', NULL),
    ('Xtreme Gaming',     'Ame',            date '2023-01-10', NULL),
    ('Xtreme Gaming',     'XinQ',           date '2023-01-10', NULL),
    ('Azure Ray',         'Somnus',         date '2023-01-10', NULL),
    ('Azure Ray',         'fy',             date '2023-01-10', NULL),
    ('Azure Ray',         'Faith_bian',     date '2023-01-10', NULL),
    ('Talon Esports',     'w33',            date '2022-01-15', NULL),
    ('Talon Esports',     'Crystallis',     date '2021-01-10', date '2022-11-01')
) AS v(team, nickname, joined_at, left_at)
JOIN teams   AS t ON t.name = v.team
JOIN players AS p ON p.nickname = v.nickname;

-- Остальные составы: каждый двенадцатый блок из пяти выдуманных игроков
-- расписывается по командам. Команда и даты выводятся из номера игрока.
INSERT INTO team_members (team_id, player_id, joined_at, left_at)
SELECT
    1 + (p.player_id * 7) % 24,
    p.player_id,
    date '2016-01-01' + ((p.player_id * 131) % 2600),
    CASE WHEN p.player_id % 3 = 0
         THEN date '2016-01-01' + ((p.player_id * 131) % 2600) + 200 + (p.player_id % 500)
         ELSE NULL END
FROM players AS p
WHERE p.player_id > 60
  AND (p.player_id - 61) % 12 < 3;

-- ---------------------------------------------------------------------
-- Турниры. Призовые близки к настоящим: у The International они
-- собираются с продаж боевого пропуска и доходили до сорока миллионов
-- долларов, а затем обвалились на порядок — это само по себе сюжет
-- для задачи про оконные функции.
-- ---------------------------------------------------------------------

INSERT INTO tournaments (tournament_id, name, prize_pool, started_at, patch_id) VALUES
    ( 1, 'The International 2015',  18429613, date '2015-08-03',  1),
    ( 2, 'The International 2016',  20770460, date '2016-08-08',  2),
    ( 3, 'The Boston Major 2016',    3000000, date '2016-12-03',  2),
    ( 4, 'The Kyiv Major 2017',      3000000, date '2017-04-27',  3),
    ( 5, 'The International 2017',  24787916, date '2017-08-07',  3),
    ( 6, 'The International 2018',  25532177, date '2018-08-20',  4),
    ( 7, 'The International 2019',  34330068, date '2019-08-20',  6),
    ( 8, 'The International 10',    40018195, date '2021-10-07', 10),
    ( 9, 'The International 11',    18930775, date '2022-10-15', 11),
    (10, 'Riyadh Masters 2023',     15000000, date '2023-07-20', 11),
    (11, 'The International 12',     3374940, date '2023-10-12', 11),
    (12, 'The International 2024',   2562000, date '2024-09-04', 12);

-- ---------------------------------------------------------------------
-- Матчи: 2500 штук с 2 мая 2015 года по 25 декабря 2024 года,
-- через каждые 2031 минуту. Турнир назначается сороковой части матчей
-- и только тем, чей год совпадает с годом турнира: в 2020 году
-- турниров нет вовсе, и все матчи того года внетурнирные.
-- Патч матча — последний, вышедший не позже дня матча.
-- ---------------------------------------------------------------------

WITH t_year AS (
    SELECT
        tournament_id,
        EXTRACT(YEAR FROM started_at)::int AS yr,
        (row_number() OVER (PARTITION BY EXTRACT(YEAR FROM started_at)
                            ORDER BY tournament_id) - 1)::int AS idx,
        count(*) OVER (PARTITION BY EXTRACT(YEAR FROM started_at))::int AS cnt
    FROM tournaments
), raw AS (
    SELECT
        g,
        timestamptz '2015-05-02 09:00:00+00' + make_interval(mins => g * 2031) AS started_at
    FROM generate_series(1, 2500) AS g
)
INSERT INTO matches (match_id, tournament_id, started_at, duration_sec, winner, patch_id)
SELECT
    7000000000 + r.g * 37,
    ty.tournament_id,
    r.started_at,
    900 + (r.g * 263) % 3901,
    CASE WHEN (r.g * 7 + r.g / 11) % 100 < 53 THEN 'radiant' ELSE 'dire' END,
    p.patch_id
FROM raw AS r
LEFT JOIN t_year AS ty
       ON r.g % 5 < 2
      AND ty.yr = EXTRACT(YEAR FROM r.started_at AT TIME ZONE 'UTC')::int
      AND ty.idx = r.g % ty.cnt
CROSS JOIN LATERAL (
    SELECT pp.patch_id
    FROM patches AS pp
    WHERE pp.released_at <= (r.started_at AT TIME ZONE 'UTC')::date
    ORDER BY pp.released_at DESC
    LIMIT 1
) AS p
ORDER BY r.g;

-- ---------------------------------------------------------------------
-- Баны: по восемь на матч, стороны чередуются. Начало окна hbase
-- то же, что и у пиков. Смещения героев в банах
-- (1, 8, 15, ... 50 по модулю 60) не пересекаются со смещениями
-- пиков (0, 7, 14, ... 56, 3), поэтому забаненного героя
-- никто в этом матче не берёт.
-- ---------------------------------------------------------------------

INSERT INTO match_bans (match_id, hero_id, side, order_no)
SELECT
    m.match_id,
    (1 + ((hb.hbase + 1 + (b - 1) * 7) % 60))::int,
    CASE WHEN b % 2 = 1 THEN 'radiant' ELSE 'dire' END,
    b::smallint
FROM matches AS m
CROSS JOIN LATERAL (
    SELECT ((m.match_id % 41) + (m.match_id % 29)) % 60 AS hbase
) AS hb
CROSS JOIN generate_series(1, 8) AS b;

-- ---------------------------------------------------------------------
-- Участники матчей: ровно десять на матч, слоты 1..5 — radiant,
-- 6..10 — dire. Игроки внутри матча различны: шаг 29 по кольцу
-- из 300 игроков за десять шагов не замыкается. Герои различны
-- по той же причине — шаг 7 по кольцу из 60.
--
-- Начало окна героев hbase — сумма двух остатков, от 41 и от 29.
-- Сумма двух равномерных величин распределена неравномерно,
-- поэтому у героев появляется разная популярность: есть те,
-- кого берут вдвое чаще прочих. Начало окна игроков pbase —
-- произведение тех же остатков: ноль выпадает часто, и игроки
-- с малыми номерами (узнаваемые профессионалы) играют больше.
--
-- Показатели согласованы: позиция слота задаёт базовый gpm
-- (кэрри зарабатывает больше саппорта), net_worth растёт
-- с длительностью матча, победившая сторона получает надбавку
-- к золоту и убийствам, проигравшая — к смертям.
-- Убийства выше у ядер (слоты 1, 2, 6, 7), помощь — у саппортов.
-- ---------------------------------------------------------------------

INSERT INTO match_players (match_id, slot, player_id, hero_id, side,
                           kills, deaths, assists, last_hits,
                           gpm, xpm, net_worth, courier_kills)
SELECT
    m.match_id,
    s.slot::smallint,
    (1 + ((hb.pbase + (s.slot - 1) * 29) % 300))::int,
    (1 + ((hb.hbase + (s.slot - 1) * 7) % 60))::int,
    c.side,
    ((ARRAY[6, 7, 4, 2, 2])[c.pos]
        + CASE WHEN w.won THEN 3 ELSE 0 END
        + (m.match_id * 7 + s.slot * 11) % 9 - 2)::int,
    ((ARRAY[4, 4, 6, 7, 7])[c.pos]
        + CASE WHEN w.won THEN 0 ELSE 2 END
        + (m.match_id * 5 + s.slot * 13) % 7 - 3)::int,
    ((ARRAY[8, 8, 11, 15, 16])[c.pos]
        + CASE WHEN w.won THEN 4 ELSE 0 END
        + (m.match_id * 11 + s.slot * 3) % 12 - 5)::int,
    (c.dur_min * (ARRAY[7, 6, 4, 2, 1])[c.pos]
        + (m.match_id + s.slot) % 20)::int,
    q.gpm,
    (q.gpm + 40 + ((m.match_id * 17 + s.slot * 23) % 120) - 60)::int,
    (q.gpm * c.dur_min * 9 / 10 + (m.match_id * 7 + s.slot * 11) % 1500)::int,
    (CASE WHEN (m.match_id * 31 + s.slot * 7) % 23 = 0
          THEN 1 + (m.match_id + s.slot) % 2 ELSE 0 END)::int
FROM matches AS m
CROSS JOIN generate_series(1, 10) AS s(slot)
CROSS JOIN LATERAL (
    SELECT ((m.match_id % 41) + (m.match_id % 29)) % 60  AS hbase,
           ((m.match_id % 41) * (m.match_id % 29)) % 300 AS pbase
) AS hb
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN s.slot <= 5 THEN 'radiant' ELSE 'dire' END AS side,
        ((s.slot - 1) % 5) + 1                               AS pos,
        m.duration_sec / 60                                  AS dur_min
) AS c
CROSS JOIN LATERAL (SELECT c.side = m.winner AS won) AS w
CROSS JOIN LATERAL (
    SELECT ((ARRAY[520, 470, 400, 300, 250])[c.pos]
            + (m.match_id * 13 + s.slot * 29) % 160 - 60
            + CASE WHEN w.won THEN 60 ELSE 0 END)::int AS gpm
) AS q;

-- ---------------------------------------------------------------------
-- Предметы. Три слоя: базовые покупки из лавки, собираемые предметы
-- и свитки рецептов (is_recipe = true). Идентификатор выдаётся
-- row_number по (слой, имя) — порядок задан, значит воспроизводим.
-- ---------------------------------------------------------------------

INSERT INTO items (item_id, name, cost, is_recipe)
SELECT
    (row_number() OVER (ORDER BY v.tier, v.name))::int,
    v.name,
    v.cost,
    v.tier = 3
FROM (VALUES
    -- слой 1: базовые предметы, ни из чего не собираются
    (1, 'Iron Branch',                50),
    (1, 'Gauntlets of Strength',     140),
    (1, 'Slippers of Agility',       140),
    (1, 'Mantle of Intelligence',    140),
    (1, 'Circlet',                   155),
    (1, 'Belt of Strength',          450),
    (1, 'Band of Elvenskin',         450),
    (1, 'Robe of the Magi',          450),
    (1, 'Crown',                     450),
    (1, 'Ogre Axe',                 1000),
    (1, 'Blade of Alacrity',        1000),
    (1, 'Staff of Wizardry',        1000),
    (1, 'Quarterstaff',              875),
    (1, 'Blades of Attack',          450),
    (1, 'Chainmail',                 550),
    (1, 'Helm of Iron Will',         950),
    (1, 'Broadsword',               1000),
    (1, 'Claymore',                 1350),
    (1, 'Mithril Hammer',           1600),
    (1, 'Javelin',                  1100),
    (1, 'Gloves of Haste',           450),
    (1, 'Boots of Speed',            500),
    (1, 'Ring of Protection',        175),
    (1, 'Sage''s Mask',              175),
    (1, 'Magic Stick',               200),
    (1, 'Fluffy Hat',                250),
    (1, 'Ring of Regen',             175),
    (1, 'Voodoo Mask',               400),
    (1, 'Blight Stone',              300),
    (1, 'Cloak',                     550),
    (1, 'Talisman of Evasion',      1300),
    (1, 'Eaglesong',                2800),
    (1, 'Reaver',                   2800),
    (1, 'Mystic Staff',             2800),
    (1, 'Demon Edge',               2200),
    (1, 'Sacred Relic',             3400),
    (1, 'Hyperstone',               2000),
    (1, 'Ultimate Orb',             2050),
    (1, 'Point Booster',            1200),
    (1, 'Vitality Booster',         1100),
    (1, 'Energy Booster',            900),
    (1, 'Void Stone',                825),
    (1, 'Ring of Health',            700),
    (1, 'Platemail',                1400),
    (1, 'Shadow Amulet',            1600),
    (1, 'Stout Shield',              200),
    (1, 'Wind Lace',                 250),
    (1, 'Blink Dagger',             2250),
    -- слой 2: собираемые предметы
    (2, 'Magic Wand',                450),
    (2, 'Bracer',                    505),
    (2, 'Null Talisman',             505),
    (2, 'Wraith Band',               505),
    (2, 'Headdress',                 425),
    (2, 'Ring of Basilius',          425),
    (2, 'Soul Ring',                 735),
    (2, 'Urn of Shadows',            725),
    (2, 'Power Treads',             1400),
    (2, 'Phase Boots',              1500),
    (2, 'Arcane Boots',             1400),
    (2, 'Tranquil Boots',            925),
    (2, 'Boots of Travel',          2500),
    (2, 'Hand of Midas',            2050),
    (2, 'Perseverance',             1700),
    (2, 'Oblivion Staff',           1775),
    (2, 'Crystalys',                2050),
    (2, 'Vanguard',                 2000),
    (2, 'Hood of Defiance',         1450),
    (2, 'Medallion of Courage',     1075),
    (2, 'Yasha',                    2050),
    (2, 'Sange',                    2050),
    (2, 'Kaya',                     2050),
    (2, 'Dragon Lance',             1900),
    (2, 'Maelstrom',                2700),
    (2, 'Morbid Mask',               900),
    (2, 'Mask of Madness',          1775),
    (2, 'Helm of the Dominator',    2400),
    (2, 'Mekansm',                  1775),
    (2, 'Vladmir''s Offering',      2050),
    (2, 'Pipe of Insight',          3025),
    (2, 'Guardian Greaves',         4950),
    (2, 'Solar Crest',              2375),
    (2, 'Black King Bar',           4050),
    (2, 'Battle Fury',              4100),
    (2, 'Daedalus',                 5150),
    (2, 'Butterfly',                4975),
    (2, 'Divine Rapier',            5600),
    (2, 'Radiance',                 4700),
    (2, 'Satanic',                  5050),
    (2, 'Heart of Tarrasque',       5000),
    (2, 'Assault Cuirass',          5125),
    (2, 'Shiva''s Guard',           4800),
    (2, 'Skull Basher',             2875),
    (2, 'Abyssal Blade',            6200),
    (2, 'Mjollnir',                 5600),
    (2, 'Manta Style',              4600),
    (2, 'Sange and Yasha',          4100),
    (2, 'Heaven''s Halberd',        3350),
    (2, 'Orchid Malevolence',       3550),
    (2, 'Bloodthorn',               6800),
    (2, 'Linken''s Sphere',         4800),
    (2, 'Eye of Skadi',             5300),
    (2, 'Aghanim''s Scepter',       4200),
    (2, 'Refresher Orb',            5000),
    (2, 'Soul Booster',             3200),
    (2, 'Octarine Core',            6000),
    (2, 'Bloodstone',               5250),
    (2, 'Shadow Blade',             3000),
    (2, 'Silver Edge',              5450),
    (2, 'Glimmer Cape',             2150),
    (2, 'Force Staff',              2200),
    (2, 'Hurricane Pike',           4600),
    (2, 'Eul''s Scepter of Divinity', 2725),
    (2, 'Echo Sabre',               2775),
    (2, 'Harpoon',                  4500),
    (2, 'Scythe of Vyse',           5675),
    (2, 'Lotus Orb',                3925),
    (2, 'Monkey King Bar',          4975),
    (2, 'Desolator',                3500),
    (2, 'Blade Mail',               2100),
    (2, 'Diffusal Blade',           2500),
    (2, 'Moon Shard',               4000),
    (2, 'Aether Lens',              2275),
    (2, 'Veil of Discord',          1900),
    (2, 'Dagon',                    2700),
    (2, 'Meteor Hammer',            2400),
    -- слой 3: свитки рецептов
    (3, 'Recipe: Boots of Travel',  2000),
    (3, 'Recipe: Hand of Midas',    1600),
    (3, 'Recipe: Mekansm',           800),
    (3, 'Recipe: Vladmir''s Offering', 1200),
    (3, 'Recipe: Pipe of Insight',  1150),
    (3, 'Recipe: Guardian Greaves', 1775),
    (3, 'Recipe: Black King Bar',   1450),
    (3, 'Recipe: Battle Fury',        50),
    (3, 'Recipe: Daedalus',          900),
    (3, 'Recipe: Radiance',         1300),
    (3, 'Recipe: Satanic',          1350),
    (3, 'Recipe: Heart of Tarrasque', 1100),
    (3, 'Recipe: Assault Cuirass',  1175),
    (3, 'Recipe: Shiva''s Guard',    600),
    (3, 'Recipe: Skull Basher',     1325),
    (3, 'Recipe: Abyssal Blade',    1325),
    (3, 'Recipe: Mjollnir',          900),
    (3, 'Recipe: Manta Style',       500),
    (3, 'Recipe: Bloodthorn',       1200),
    (3, 'Recipe: Linken''s Sphere', 1050),
    (3, 'Recipe: Refresher Orb',    1525),
    (3, 'Recipe: Shadow Blade',       50),
    (3, 'Recipe: Silver Edge',       400),
    (3, 'Recipe: Hurricane Pike',    500),
    (3, 'Recipe: Eul''s Scepter of Divinity', 650),
    (3, 'Recipe: Harpoon',          1725),
    (3, 'Recipe: Lotus Orb',        1325),
    (3, 'Recipe: Monkey King Bar',  1675),
    (3, 'Recipe: Dagon',            1250),
    (3, 'Recipe: Meteor Hammer',     950),
    (3, 'Recipe: Force Staff',      1025)
) AS v(tier, name, cost);

-- Рецепты. Дерево сборки доходит до четырёх уровней:
-- Guardian Greaves -> Mekansm -> Headdress -> Ring of Regen,
-- Bloodthorn -> Orchid Malevolence -> Oblivion Staff -> Quarterstaff,
-- Harpoon -> Echo Sabre -> Oblivion Staff -> Robe of the Magi.
-- Циклов нет: ребро всегда идёт от предмета более высокого слоя
-- к предмету более низкого.

INSERT INTO item_recipe (item_id, component_id, quantity)
SELECT i.item_id, c.item_id, v.qty
FROM (VALUES
    ('Magic Wand', 'Magic Stick', 1), ('Magic Wand', 'Iron Branch', 3),
    ('Bracer', 'Gauntlets of Strength', 1), ('Bracer', 'Circlet', 1),
    ('Null Talisman', 'Mantle of Intelligence', 1), ('Null Talisman', 'Circlet', 1),
    ('Wraith Band', 'Slippers of Agility', 1), ('Wraith Band', 'Circlet', 1),
    ('Headdress', 'Ring of Regen', 1), ('Headdress', 'Fluffy Hat', 1),
    ('Ring of Basilius', 'Sage''s Mask', 1), ('Ring of Basilius', 'Ring of Protection', 1),
    ('Soul Ring', 'Ring of Regen', 1), ('Soul Ring', 'Sage''s Mask', 1),
    ('Urn of Shadows', 'Sage''s Mask', 1), ('Urn of Shadows', 'Circlet', 2),
    ('Power Treads', 'Boots of Speed', 1), ('Power Treads', 'Gloves of Haste', 1),
    ('Power Treads', 'Belt of Strength', 1),
    ('Phase Boots', 'Boots of Speed', 1), ('Phase Boots', 'Blades of Attack', 1),
    ('Phase Boots', 'Chainmail', 1),
    ('Arcane Boots', 'Boots of Speed', 1), ('Arcane Boots', 'Energy Booster', 1),
    ('Tranquil Boots', 'Boots of Speed', 1), ('Tranquil Boots', 'Ring of Regen', 1),
    ('Tranquil Boots', 'Wind Lace', 1),
    ('Boots of Travel', 'Boots of Speed', 1), ('Boots of Travel', 'Recipe: Boots of Travel', 1),
    ('Hand of Midas', 'Gloves of Haste', 1), ('Hand of Midas', 'Recipe: Hand of Midas', 1),
    ('Perseverance', 'Ring of Health', 1), ('Perseverance', 'Void Stone', 1),
    ('Oblivion Staff', 'Quarterstaff', 1), ('Oblivion Staff', 'Robe of the Magi', 1),
    ('Oblivion Staff', 'Blades of Attack', 1),
    ('Crystalys', 'Blades of Attack', 1), ('Crystalys', 'Broadsword', 1),
    ('Vanguard', 'Ring of Health', 1), ('Vanguard', 'Stout Shield', 1),
    ('Vanguard', 'Vitality Booster', 1),
    ('Hood of Defiance', 'Ring of Health', 1), ('Hood of Defiance', 'Cloak', 1),
    ('Medallion of Courage', 'Chainmail', 1), ('Medallion of Courage', 'Blight Stone', 1),
    ('Yasha', 'Blade of Alacrity', 1), ('Yasha', 'Band of Elvenskin', 1),
    ('Sange', 'Ogre Axe', 1), ('Sange', 'Belt of Strength', 1),
    ('Kaya', 'Staff of Wizardry', 1), ('Kaya', 'Robe of the Magi', 1),
    ('Dragon Lance', 'Ogre Axe', 1), ('Dragon Lance', 'Band of Elvenskin', 2),
    ('Maelstrom', 'Mithril Hammer', 1), ('Maelstrom', 'Javelin', 1),
    ('Morbid Mask', 'Voodoo Mask', 1),
    ('Mask of Madness', 'Morbid Mask', 1), ('Mask of Madness', 'Gloves of Haste', 1),
    ('Helm of the Dominator', 'Helm of Iron Will', 1),
    ('Helm of the Dominator', 'Morbid Mask', 1),
    ('Mekansm', 'Headdress', 1), ('Mekansm', 'Chainmail', 1),
    ('Mekansm', 'Recipe: Mekansm', 1),
    ('Vladmir''s Offering', 'Ring of Basilius', 1), ('Vladmir''s Offering', 'Headdress', 1),
    ('Vladmir''s Offering', 'Recipe: Vladmir''s Offering', 1),
    ('Pipe of Insight', 'Hood of Defiance', 1), ('Pipe of Insight', 'Headdress', 1),
    ('Pipe of Insight', 'Recipe: Pipe of Insight', 1),
    ('Guardian Greaves', 'Mekansm', 1), ('Guardian Greaves', 'Arcane Boots', 1),
    ('Guardian Greaves', 'Recipe: Guardian Greaves', 1),
    ('Solar Crest', 'Medallion of Courage', 1), ('Solar Crest', 'Wind Lace', 1),
    ('Solar Crest', 'Blight Stone', 1),
    ('Black King Bar', 'Ogre Axe', 1), ('Black King Bar', 'Mithril Hammer', 1),
    ('Black King Bar', 'Recipe: Black King Bar', 1),
    ('Battle Fury', 'Broadsword', 1), ('Battle Fury', 'Claymore', 1),
    ('Battle Fury', 'Perseverance', 1), ('Battle Fury', 'Recipe: Battle Fury', 1),
    ('Daedalus', 'Crystalys', 1), ('Daedalus', 'Demon Edge', 1),
    ('Daedalus', 'Recipe: Daedalus', 1),
    ('Butterfly', 'Talisman of Evasion', 1), ('Butterfly', 'Eaglesong', 1),
    ('Butterfly', 'Quarterstaff', 1),
    ('Divine Rapier', 'Demon Edge', 1), ('Divine Rapier', 'Sacred Relic', 1),
    ('Radiance', 'Sacred Relic', 1), ('Radiance', 'Recipe: Radiance', 1),
    ('Satanic', 'Reaver', 1), ('Satanic', 'Morbid Mask', 1),
    ('Satanic', 'Recipe: Satanic', 1),
    ('Heart of Tarrasque', 'Reaver', 1), ('Heart of Tarrasque', 'Vitality Booster', 1),
    ('Heart of Tarrasque', 'Recipe: Heart of Tarrasque', 1),
    ('Assault Cuirass', 'Hyperstone', 1), ('Assault Cuirass', 'Platemail', 1),
    ('Assault Cuirass', 'Chainmail', 1), ('Assault Cuirass', 'Recipe: Assault Cuirass', 1),
    ('Shiva''s Guard', 'Platemail', 1), ('Shiva''s Guard', 'Mystic Staff', 1),
    ('Shiva''s Guard', 'Recipe: Shiva''s Guard', 1),
    ('Skull Basher', 'Javelin', 1), ('Skull Basher', 'Belt of Strength', 1),
    ('Skull Basher', 'Recipe: Skull Basher', 1),
    ('Abyssal Blade', 'Skull Basher', 1), ('Abyssal Blade', 'Vanguard', 1),
    ('Abyssal Blade', 'Recipe: Abyssal Blade', 1),
    ('Mjollnir', 'Maelstrom', 1), ('Mjollnir', 'Hyperstone', 1),
    ('Mjollnir', 'Recipe: Mjollnir', 1),
    ('Manta Style', 'Yasha', 1), ('Manta Style', 'Ultimate Orb', 1),
    ('Manta Style', 'Recipe: Manta Style', 1),
    ('Sange and Yasha', 'Sange', 1), ('Sange and Yasha', 'Yasha', 1),
    ('Heaven''s Halberd', 'Sange', 1), ('Heaven''s Halberd', 'Talisman of Evasion', 1),
    ('Orchid Malevolence', 'Oblivion Staff', 2),
    ('Bloodthorn', 'Orchid Malevolence', 1), ('Bloodthorn', 'Crystalys', 1),
    ('Bloodthorn', 'Recipe: Bloodthorn', 1),
    ('Linken''s Sphere', 'Perseverance', 1), ('Linken''s Sphere', 'Ultimate Orb', 1),
    ('Linken''s Sphere', 'Recipe: Linken''s Sphere', 1),
    ('Eye of Skadi', 'Ultimate Orb', 2), ('Eye of Skadi', 'Point Booster', 1),
    ('Aghanim''s Scepter', 'Point Booster', 1), ('Aghanim''s Scepter', 'Ogre Axe', 1),
    ('Aghanim''s Scepter', 'Blade of Alacrity', 1),
    ('Aghanim''s Scepter', 'Staff of Wizardry', 1),
    ('Refresher Orb', 'Perseverance', 1), ('Refresher Orb', 'Oblivion Staff', 1),
    ('Refresher Orb', 'Recipe: Refresher Orb', 1),
    ('Soul Booster', 'Point Booster', 1), ('Soul Booster', 'Vitality Booster', 1),
    ('Soul Booster', 'Energy Booster', 1),
    ('Octarine Core', 'Soul Booster', 1), ('Octarine Core', 'Mystic Staff', 1),
    ('Bloodstone', 'Soul Booster', 1), ('Bloodstone', 'Kaya', 1),
    ('Shadow Blade', 'Shadow Amulet', 1), ('Shadow Blade', 'Claymore', 1),
    ('Shadow Blade', 'Recipe: Shadow Blade', 1),
    ('Silver Edge', 'Shadow Blade', 1), ('Silver Edge', 'Ultimate Orb', 1),
    ('Silver Edge', 'Recipe: Silver Edge', 1),
    ('Glimmer Cape', 'Shadow Amulet', 1), ('Glimmer Cape', 'Cloak', 1),
    ('Force Staff', 'Staff of Wizardry', 1), ('Force Staff', 'Ring of Regen', 1),
    ('Force Staff', 'Recipe: Force Staff', 1),
    ('Hurricane Pike', 'Force Staff', 1), ('Hurricane Pike', 'Dragon Lance', 1),
    ('Hurricane Pike', 'Recipe: Hurricane Pike', 1),
    ('Eul''s Scepter of Divinity', 'Staff of Wizardry', 1),
    ('Eul''s Scepter of Divinity', 'Wind Lace', 1),
    ('Eul''s Scepter of Divinity', 'Void Stone', 1),
    ('Eul''s Scepter of Divinity', 'Recipe: Eul''s Scepter of Divinity', 1),
    ('Echo Sabre', 'Oblivion Staff', 1), ('Echo Sabre', 'Ogre Axe', 1),
    ('Harpoon', 'Echo Sabre', 1), ('Harpoon', 'Recipe: Harpoon', 1),
    ('Scythe of Vyse', 'Mystic Staff', 1), ('Scythe of Vyse', 'Ultimate Orb', 1),
    ('Scythe of Vyse', 'Void Stone', 1),
    ('Lotus Orb', 'Perseverance', 1), ('Lotus Orb', 'Energy Booster', 1),
    ('Lotus Orb', 'Recipe: Lotus Orb', 1),
    ('Monkey King Bar', 'Demon Edge', 1), ('Monkey King Bar', 'Javelin', 1),
    ('Monkey King Bar', 'Recipe: Monkey King Bar', 1),
    ('Desolator', 'Mithril Hammer', 2),
    ('Blade Mail', 'Broadsword', 1), ('Blade Mail', 'Chainmail', 1),
    ('Blade Mail', 'Robe of the Magi', 1),
    ('Diffusal Blade', 'Blade of Alacrity', 2), ('Diffusal Blade', 'Robe of the Magi', 1),
    ('Moon Shard', 'Hyperstone', 2),
    ('Aether Lens', 'Energy Booster', 1), ('Aether Lens', 'Void Stone', 1),
    ('Veil of Discord', 'Crown', 2), ('Veil of Discord', 'Ring of Basilius', 1),
    ('Dagon', 'Staff of Wizardry', 1), ('Dagon', 'Crown', 1),
    ('Dagon', 'Recipe: Dagon', 1),
    ('Meteor Hammer', 'Crown', 1), ('Meteor Hammer', 'Staff of Wizardry', 1),
    ('Meteor Hammer', 'Ring of Regen', 1), ('Meteor Hammer', 'Recipe: Meteor Hammer', 1)
) AS v(item, component, qty)
JOIN items AS i ON i.name = v.item
JOIN items AS c ON c.name = v.component;

-- ---------------------------------------------------------------------
-- Покупки в матчах: ровно три дорогих предмета на каждое участие.
-- Шаг 19 по кольцу из 64 предметов дороже 2000 золота даёт три
-- различных предмета, а момент покупки привязан к длительности матча:
-- 20 %, 45 % и 70 % от неё.
-- ---------------------------------------------------------------------

WITH pool AS (
    SELECT
        item_id,
        (row_number() OVER (ORDER BY item_id) - 1)::int AS idx,
        (count(*) OVER ())::int AS n
    FROM items
    WHERE is_recipe = false AND cost >= 2000
)
INSERT INTO match_items (match_id, slot, item_id, bought_at_sec)
SELECT
    mp.match_id,
    mp.slot,
    pool.item_id,
    (m.duration_sec * (20 + k * 25) / 100 + (mp.match_id + mp.slot * 7) % 120)::int
FROM match_players AS mp
JOIN matches AS m ON m.match_id = mp.match_id
CROSS JOIN generate_series(0, 2) AS k
JOIN pool ON pool.idx = ((mp.match_id * 13 + mp.slot * 7 + k * 19) % pool.n);

-- ---------------------------------------------------------------------
-- Стримеры. Шестнадцать из сорока привязаны к строке в players:
-- это те, кто и стримит, и выступает за команду. Отсюда растёт
-- цепочка streamers -> players -> team_members -> teams.
-- У остальных player_id пустой.
-- ---------------------------------------------------------------------

INSERT INTO streamers (streamer_id, nickname, platform_id, player_id, followers, started_at)
SELECT v.streamer_id, v.nickname, pl.platform_id, p.player_id, v.followers, v.started_at
FROM (VALUES
    ( 1, 'Dread',          'Twitch',       'Dread',          1150000, date '2011-03-14'),
    ( 2, 'NS',             'Twitch',       'NS',              680000, date '2012-06-01'),
    ( 3, 'SingSing',       'Twitch',       'SingSing',       1420000, date '2012-01-20'),
    ( 4, 'AdmiralBulldog', 'Twitch',       'AdmiralBulldog',  980000, date '2013-05-02'),
    ( 5, 'Solo',           'Twitch',       'Solo',            410000, date '2016-02-11'),
    ( 6, 'Dendi',          'Twitch',       'Dendi',          1250000, date '2013-09-01'),
    ( 7, 'Collapse',       'Twitch',       'Collapse',        520000, date '2021-01-15'),
    ( 8, 'Yatoro',         'Twitch',       'Yatoro',          610000, date '2021-02-01'),
    ( 9, 'Miracle-',       'Twitch',       'Miracle-',        870000, date '2016-04-01'),
    (10, 'RAMZES666',      'VK Play Live', 'RAMZES666',       540000, date '2017-08-01'),
    (11, 'No[o]ne',        'Twitch',       'No[o]ne',         330000, date '2017-09-01'),
    (12, 'Resolut1on',     'Twitch',       'Resolut1on',      290000, date '2016-05-01'),
    (13, 'ALOHADANCE',     'Twitch',       'ALOHADANCE',      260000, date '2015-11-01'),
    (14, 'Arteezy',        'Twitch',       'Arteezy',        1080000, date '2013-07-01'),
    (15, 'Puppey',         'Twitch',       'Puppey',          450000, date '2014-10-01'),
    (16, 'gpk',            'VK Play Live', 'gpk',             180000, date '2020-03-01'),
    (17, 'Вжлинк',         'VK Play Live', NULL,             1400000, date '2016-01-20'),
    (18, 'Папич',          'VK Play Live', NULL,             1900000, date '2014-03-01'),
    (19, 'Stray228',       'Twitch',       NULL,             1350000, date '2015-06-01'),
    (20, 'Evelone192',     'Kick',         NULL,             1600000, date '2016-09-01'),
    (21, 'Mob',            'Twitch',       NULL,              430000, date '2017-02-01'),
    (22, 'Gorgc',          'Twitch',       NULL,              760000, date '2016-07-01'),
    (23, 'Grubby',         'Twitch',       NULL,              690000, date '2011-01-10'),
    (24, 'BSJ',            'Twitch',       NULL,              350000, date '2015-03-01'),
    (25, 'Jenkins',        'Twitch',       NULL,              240000, date '2016-11-01'),
    (26, 'Purge',          'Twitch',       NULL,              320000, date '2012-02-01'),
    (27, 'SUNSfan',        'Twitch',       NULL,              210000, date '2013-04-01'),
    (28, 'slacks',         'Twitch',       NULL,              190000, date '2013-04-15'),
    (29, 'ODPixel',        'YouTube',      NULL,              410000, date '2014-05-01'),
    (30, 'Ephey',          'Twitch',       NULL,              120000, date '2017-06-01'),
    (31, 'Lacoste',        'Twitch',       NULL,              150000, date '2016-10-01'),
    (32, 'Kyle',           'Twitch',       NULL,              170000, date '2015-01-05'),
    (33, 'Maut',           'VK Play Live', NULL,               95000, date '2019-04-01'),
    (34, 'Smile',          'VK Play Live', NULL,               88000, date '2018-02-01'),
    (35, 'Nix',            'VK Play Live', NULL,               76000, date '2018-08-01'),
    (36, 'Tobiwan',        'YouTube',      NULL,              280000, date '2012-12-01'),
    (37, 'Blitz',          'Twitch',       NULL,              330000, date '2014-08-01'),
    (38, 'qojqva',         'Twitch',       NULL,              260000, date '2013-06-01'),
    (39, 'Maddyson',       'VK Play Live', NULL,             1100000, date '2013-01-01'),
    (40, 'Vanskor',        'YouTube',      NULL,              140000, date '2017-03-01')
) AS v(streamer_id, nickname, platform, player, followers, started_at)
JOIN platforms AS pl ON pl.name = v.platform
LEFT JOIN players AS p ON p.nickname = v.player;

-- ---------------------------------------------------------------------
-- Стримы: по 75 на каждого из сорока стримеров, с 1 января 2021 года
-- по ноябрь 2024-го. Пик зрителей привязан к числу подписчиков,
-- средний онлайн составляет от 45 до 69 процентов пика.
-- ---------------------------------------------------------------------

INSERT INTO streams (stream_id, streamer_id, started_at, duration_min,
                     peak_viewers, avg_viewers, title)
SELECT
    900000000 + g,
    st.streamer_id,
    timestamptz '2021-01-01 00:00:00+00'
        + make_interval(days  => ((g - 1) / 40) * 19 + ((g - 1) % 40) % 7,
                        hours => 11 + (g * 7) % 9),
    60 + (g * 137) % 541,
    pk.peak,
    (pk.peak * (45 + g % 25) / 100)::int,
    CASE WHEN g % 3 = 0 THEN tt.tmpl ELSE tt.tmpl || ' — ' || h.name END
FROM generate_series(1, 3000) AS g
JOIN streamers AS st ON st.streamer_id = 1 + (g - 1) % 40
JOIN heroes    AS h  ON h.hero_id      = 1 + (g * 23) % 60
CROSS JOIN LATERAL (
    SELECT (st.followers / 90 + (g * 53) % 400 + 50)::int AS peak
) AS pk
CROSS JOIN LATERAL (
    SELECT (ARRAY[
        'Рейтинг до тысячи',
        'Калибровка с нуля',
        'Пати с подписчиками',
        'Разбор реплеев',
        'Смотрим мейджор',
        'Паблик на удачу',
        'Турнирный день',
        'Отыгрываем ММР',
        'Челлендж: только саппорт',
        'Пробуем новый патч',
        'Утренний паблик',
        'Ночной рейтинг',
        'Обучаем новичков',
        'Один герой весь стрим',
        'Ранкед до победного',
        'Смотрим чужие катки'])[1 + (g * 11) % 16] AS tmpl
) AS tt
ORDER BY g;

-- ---------------------------------------------------------------------
-- Донаты: от нуля до двадцати на стрим по остатку от деления номера
-- стрима на 21. Каждый двадцать первый стрим остаётся без донатов —
-- материал для задач на LEFT JOIN и COALESCE.
-- ---------------------------------------------------------------------

WITH d AS (
    SELECT s.stream_id, s.duration_min, k
    FROM streams AS s
    CROSS JOIN LATERAL generate_series(1, ((s.stream_id - 900000001) % 21)::int) AS k
)
INSERT INTO stream_donations (donation_id, stream_id, amount, sent_at_sec, nickname)
SELECT
    row_number() OVER (ORDER BY d.stream_id, d.k),
    d.stream_id,
    (25 + (d.stream_id * 37 + d.k * 101) % 4975)::numeric + (d.k % 4) * 0.25,
    ((d.stream_id * 211 + d.k * 613) % (d.duration_min * 60))::int,
    (ARRAY['mega', 'pro', 'dark', 'true', 'last', 'neo', 'old', 'big',
           'soft', 'zero'])[1 + (d.stream_id + d.k) % 10]
    || (ARRAY['pudge', 'invoker', 'techies', 'carry', 'support', 'gamer',
              'fan', 'wizard', 'creep', 'rune', 'ward', 'midas'])[1 + (d.stream_id * 3 + d.k * 7) % 12]
    || ((d.stream_id + d.k * 13) % 1000)::text
FROM d;

-- Статистика распределения нужна оптимизатору.
ANALYZE;

SELECT 'platforms' AS "таблица", count(*) AS "строк" FROM platforms
UNION ALL SELECT 'patches',          count(*) FROM patches
UNION ALL SELECT 'heroes',           count(*) FROM heroes
UNION ALL SELECT 'hero_roles',       count(*) FROM hero_roles
UNION ALL SELECT 'players',          count(*) FROM players
UNION ALL SELECT 'teams',            count(*) FROM teams
UNION ALL SELECT 'team_members',     count(*) FROM team_members
UNION ALL SELECT 'tournaments',      count(*) FROM tournaments
UNION ALL SELECT 'matches',          count(*) FROM matches
UNION ALL SELECT 'match_bans',       count(*) FROM match_bans
UNION ALL SELECT 'match_players',    count(*) FROM match_players
UNION ALL SELECT 'items',            count(*) FROM items
UNION ALL SELECT 'item_recipe',      count(*) FROM item_recipe
UNION ALL SELECT 'match_items',      count(*) FROM match_items
UNION ALL SELECT 'streamers',        count(*) FROM streamers
UNION ALL SELECT 'streams',          count(*) FROM streams
UNION ALL SELECT 'stream_donations', count(*) FROM stream_donations
ORDER BY 1;
