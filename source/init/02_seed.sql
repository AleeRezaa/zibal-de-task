SELECT setseed(0.42);          -- reproducible data
SET work_mem = '256MB';

-- 2,000 merchants; provinces skewed toward the first entries (Tehran most common)
INSERT INTO core.merchants
SELECT
    g,
    (ARRAY['Pars','Arya','Kian','Sepehr','Nik','Rayan','Tak','Mehr','Avin','Saman'])[1 + floor(random()*10)::int]
      || ' ' ||
    (ARRAY['Market','Cafe','Pharmacy','Electronics','Restaurant','Fuel','Clothing','Hotel','Online Shop','Bakery'])[1 + floor(random()*10)::int]
      || ' #' || g,
    (ARRAY['5411','5812','5912','5732','5541','5651','7011','5999','4121','5462'])[1 + floor(random()*10)::int],
    (ARRAY['Tehran','Isfahan','Khorasan Razavi','Fars','East Azerbaijan','Khuzestan','Alborz','Mazandaran',
           'Gilan','Kerman','West Azerbaijan','Hormozgan','Yazd','Qom','Markazi','Golestan','Hamadan',
           'Kermanshah','Lorestan','Sistan and Baluchestan','Ardabil','Qazvin','Zanjan','Semnan','Kurdistan',
           'Bushehr','Chaharmahal and Bakhtiari','Kohgiluyeh and Boyer-Ahmad','North Khorasan',
           'South Khorasan','Ilam'])[1 + floor(power(random(), 2) * 31)::int],
    CASE WHEN x.r < 0.70 THEN 'LOW' WHEN x.r < 0.92 THEN 'MEDIUM' ELSE 'HIGH' END,
    lpad(floor(random() * 1e10)::bigint::text, 10, '0'),
    '09' || lpad(floor(random() * 1e9)::bigint::text, 9, '0'),
    now() - interval '200 days'
FROM generate_series(1, 2000) AS g
CROSS JOIN LATERAL (SELECT random() + g*0 AS r) AS x;

-- 5,000,000 transactions over the last 180 days: 80% SUCCESS / 10% FAILED / 10% REVERSED
INSERT INTO core.transactions
    (merchant_id, channel, card_bin, amount, fee_amount, status, created_at, updated_at)
SELECT merchant_id, channel, card_bin, amount, fee_amount, status, created_at, updated_at
FROM (
    SELECT
        1 + floor(power(v.m, 1.5) * 2000)::bigint                         AS merchant_id,
        CASE WHEN v.c < 0.60 THEN 'POS' WHEN v.c < 0.90 THEN 'IPG' ELSE 'QR' END AS channel,
        (ARRAY['603799','589210','627648','627961','603770','628023','627760','502229','636214','622106'])
            [1 + floor(v.b * 10)::int]                                    AS card_bin,
        v.amount,
        greatest(v.amount * 2 / 1000, 1000)                               AS fee_amount,   -- 0.2%, min 1,000 IRR
        CASE WHEN v.s < 0.80 THEN 'SUCCESS' WHEN v.s < 0.90 THEN 'FAILED' ELSE 'REVERSED' END AS status,
        v.ts                                                              AS created_at,
        v.ts + make_interval(secs => 2 + v.c * 60)                        AS updated_at
    FROM generate_series(1, 5000000) AS g
    CROSS JOIN LATERAL (
        SELECT random() + g*0 AS m, random() + g*0 AS c, random() + g*0 AS b, random() + g*0 AS s,
               (round(10000 * power(5000, random() + g*0), -3))::bigint AS amount,   -- 10k .. 50M IRR
               now() - (random() + g*0) * interval '180 days'          AS ts
    ) AS v
) t
ORDER BY created_at;

ANALYZE core.merchants;
ANALYZE core.transactions;