WITH paid_sessions AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM sessions AS s
    WHERE LOWER(s.medium) IN (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
),

ranked_attribution AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY
                ps.visit_date DESC
        ) AS rn
    FROM paid_sessions AS ps
    LEFT JOIN leads AS l
        ON
            ps.visitor_id = l.visitor_id
            AND
            ps.visit_date <= l.created_at
),

attributed_leads AS (
    SELECT
        ra.visitor_id,
        ra.visit_date,
        ra.utm_source,
        ra.utm_medium,
        ra.utm_campaign,
        ra.lead_id,
        ra.created_at,
        ra.amount,
        ra.closing_reason,
        ra.status_id
    FROM ranked_attribution AS ra
    WHERE
        ra.lead_id IS NOT NULL
        AND
        ra.rn = 1
)

SELECT
    ps.visitor_id,
    ps.visit_date,
    ps.utm_source,
    ps.utm_medium,
    ps.utm_campaign,
    al.lead_id,
    al.created_at,
    al.amount,
    al.closing_reason,
    al.status_id
FROM paid_sessions AS ps
LEFT JOIN attributed_leads AS al
    ON
        ps.visitor_id = al.visitor_id
        AND ps.visit_date = al.visit_date
        AND ps.utm_source = al.utm_source
        AND ps.utm_medium = al.utm_medium
        AND ps.utm_campaign = al.utm_campaign
ORDER BY
    al.amount DESC NULLS LAST,
    ps.visit_date ASC,
    ps.utm_source ASC,
    ps.utm_medium ASC,
    ps.utm_campaign ASC;