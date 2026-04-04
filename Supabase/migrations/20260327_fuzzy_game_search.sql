-- Fuzzy local game search for BGG-cached games + one-time description cleanup

CREATE OR REPLACE FUNCTION public.search_games_fuzzy(search_query TEXT, result_limit INT DEFAULT 20)
RETURNS SETOF games
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
    WITH normalized AS (
        SELECT
            trim(coalesce(search_query, '')) AS raw_query,
            lower(regexp_replace(trim(coalesce(search_query, '')), '[^[:alnum:][:space:]]+', '', 'g')) AS normalized_query,
            GREATEST(coalesce(result_limit, 20), 1) AS lim
    )
    SELECT g.*
    FROM games g
    CROSS JOIN normalized q
    WHERE q.raw_query <> ''
      AND g.bgg_id IS NOT NULL
      AND g.owner_id IS NULL
      AND (
          g.name ILIKE ('%' || q.raw_query || '%')
          OR word_similarity(
              lower(regexp_replace(g.name, '[^[:alnum:][:space:]]+', '', 'g')),
              q.normalized_query
          ) > 0.3
      )
    ORDER BY
      CASE
          WHEN lower(regexp_replace(g.name, '[^[:alnum:][:space:]]+', '', 'g')) LIKE (q.normalized_query || '%') THEN 0
          ELSE 1
      END,
      GREATEST(
          similarity(
              lower(regexp_replace(g.name, '[^[:alnum:][:space:]]+', '', 'g')),
              q.normalized_query
          ),
          word_similarity(
              lower(regexp_replace(g.name, '[^[:alnum:][:space:]]+', '', 'g')),
              q.normalized_query
          )
      ) DESC,
      g.bgg_rank ASC NULLS LAST,
      g.name ASC
    LIMIT (SELECT lim FROM normalized);
$$;

GRANT EXECUTE ON FUNCTION public.search_games_fuzzy(TEXT, INT) TO authenticated;

-- One-time cleanup for old cached BGG descriptions that still contain HTML/entities.
UPDATE games
SET description = NULLIF(
    trim(
        regexp_replace(
            regexp_replace(
                replace(
                    replace(
                        replace(
                            replace(
                                replace(
                                    replace(
                                        replace(
                                            replace(
                                                regexp_replace(
                                                    regexp_replace(
                                                        regexp_replace(coalesce(description, ''), '<br\\s*/?>', E'\\n', 'gi'),
                                                        '</p>',
                                                        E'\\n',
                                                        'gi'
                                                    ),
                                                    '<[^>]+>',
                                                    '',
                                                    'g'
                                                ),
                                                '&nbsp;',
                                                ' '
                                            ),
                                            '&amp;',
                                            '&'
                                        ),
                                        '&lt;',
                                        '<'
                                    ),
                                    '&gt;',
                                    '>'
                                ),
                                '&quot;',
                                '"'
                            ),
                            '&#39;',
                            ''''
                        ),
                        E'\\r\\n',
                        E'\\n'
                    ),
                    E'\\n\\n\\n',
                    E'\\n\\n'
                ),
                E'\\n{3,}',
                E'\\n\\n',
                'g'
            ),
            '[[:space:]]+$',
            '',
            'g'
        )
    ),
    ''
)
WHERE description IS NOT NULL
  AND (
      description ~* '<[^>]+>'
      OR description ~* '&(amp|lt|gt|quot|nbsp|#39);'
  );
