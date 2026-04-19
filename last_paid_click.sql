WITH last_paid_click AS (
    SELECT DISTINCT ON (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM sessions AS s
    WHERE LOWER(s.medium) != 'organic'
    ORDER BY
        s.visitor_id ASC,
        s.visit_date DESC
),
    
attributed_leads AS (
    SELECT DISTINCT ON (l.lead_id)
        lpc.visitor_id,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid_click AS lpc
    LEFT JOIN leads AS l
        ON 
            lpc.visitor_id = l.visitor_id
            AND lpc.visit_date <= l.created_at
    ORDER BY
        l.lead_id ASC,
        l.created_at ASC
)

SELECT
    al.visitor_id,
    al.visit_date,
    al.utm_source,
    al.utm_medium,
    al.utm_campaign,
    al.lead_id,
    al.created_at,
    al.amount,
    al.closing_reason,
    al.status_id
FROM attributed_leads AS al
ORDER BY
    al.amount DESC NULLS LAST,
    al.visit_date ASC,
    al.utm_source ASC,
    al.utm_medium ASC,
    al.utm_campaign ASC;
