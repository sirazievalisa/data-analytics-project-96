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

last_paid_visits AS (
    SELECT DISTINCT ON (ps.visitor_id)
        ps.visitor_id,
        ps.visit_date::date AS visit_date,
        ps.visit_date AS visit_datetime,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign
    FROM paid_sessions AS ps
    ORDER BY
        ps.visitor_id,
        ps.visit_date DESC,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign
),

visitors_agg AS (
    SELECT
        lpv.visit_date,
        lpv.utm_source,
        lpv.utm_medium,
        lpv.utm_campaign,
        COUNT(*) AS visitors_count
    FROM last_paid_visits AS lpv
    GROUP BY
        lpv.visit_date,
        lpv.utm_source,
        lpv.utm_medium,
        lpv.utm_campaign
),

first_lead_after_click AS (
    SELECT DISTINCT ON (lpv.visitor_id)
        lpv.visitor_id,
        lpv.visit_date,
        lpv.utm_source,
        lpv.utm_medium,
        lpv.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid_visits AS lpv
    LEFT JOIN leads AS l
        ON l.visitor_id = lpv.visitor_id
       AND l.created_at >= lpv.visit_datetime
    ORDER BY
        lpv.visitor_id,
        l.created_at ASC NULLS LAST,
        l.lead_id
),

leads_agg AS (
    SELECT
        flac.visit_date,
        flac.utm_source,
        flac.utm_medium,
        flac.utm_campaign,
        COUNT(flac.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN flac.closing_reason = 'Успешно реализовано'
                    OR flac.status_id = 142
                THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN flac.closing_reason = 'Успешно реализовано'
                    OR flac.status_id = 142
                THEN flac.amount
            END
        ) AS revenue
    FROM first_lead_after_click AS flac
    GROUP BY
        flac.visit_date,
        flac.utm_source,
        flac.utm_medium,
        flac.utm_campaign
),

vk_costs AS (
    SELECT
        vk.campaign_date::date AS visit_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        SUM(vk.daily_spent) AS total_cost
    FROM vk_ads AS vk
    GROUP BY
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign
),

ya_costs AS (
    SELECT
        ya.campaign_date::date AS visit_date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        SUM(ya.daily_spent) AS total_cost
    FROM ya_ads AS ya
    GROUP BY
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign
),

costs_agg AS (
    SELECT
        t.visit_date,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        SUM(t.total_cost) AS total_cost
    FROM (
        SELECT
            visit_date,
            utm_source,
            utm_medium,
            utm_campaign,
            total_cost
        FROM vk_costs

        UNION ALL

        SELECT
            visit_date,
            utm_source,
            utm_medium,
            utm_campaign,
            total_cost
        FROM ya_costs
    ) AS t
    GROUP BY
        t.visit_date,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign
)

SELECT
    va.visit_date,
    va.visitors_count,
    va.utm_source,
    va.utm_medium,
    va.utm_campaign,
    COALESCE(la.leads_count, 0) AS leads_count,
    COALESCE(la.purchases_count, 0) AS purchases_count,
    la.revenue,
    ca.total_cost
FROM visitors_agg AS va
LEFT JOIN leads_agg AS la
    ON va.visit_date = la.visit_date
   AND va.utm_source = la.utm_source
   AND va.utm_medium = la.utm_medium
   AND va.utm_campaign = la.utm_campaign
LEFT JOIN costs_agg AS ca
    ON va.visit_date = ca.visit_date
   AND va.utm_source = ca.utm_source
   AND va.utm_medium = ca.utm_medium
   AND va.utm_campaign = ca.utm_campaign
ORDER BY
    la.revenue DESC NULLS LAST,
    va.visit_date ASC,
    va.visitors_count DESC,
    va.utm_source ASC,
    va.utm_medium ASC,
    va.utm_campaign ASC;