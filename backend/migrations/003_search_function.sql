-- Vector similarity search with geo filtering
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION search_services(
    query_embedding VECTOR(384),
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    max_distance_km DOUBLE PRECISION DEFAULT 15.0,
    match_limit INTEGER DEFAULT 5,
    min_similarity DOUBLE PRECISION DEFAULT 0.3
)
RETURNS TABLE (
    service_id UUID,
    service_name TEXT,
    service_description TEXT,
    price NUMERIC,
    similarity DOUBLE PRECISION,
    master_id UUID,
    master_name TEXT,
    experience INTEGER,
    rating NUMERIC,
    distance_km DOUBLE PRECISION
)
LANGUAGE sql STABLE
AS $$
    SELECT
        s.id AS service_id,
        s.name AS service_name,
        s.description AS service_description,
        s.price,
        1 - (s.embedding <=> query_embedding) AS similarity,
        m.id AS master_id,
        m.name AS master_name,
        m.experience,
        m.rating,
        ST_Distance(
            m.location,
            ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography
        ) / 1000.0 AS distance_km
    FROM services s
    JOIN masters m ON s.master_id = m.id
    WHERE
        s.embedding IS NOT NULL
        AND 1 - (s.embedding <=> query_embedding) >= min_similarity
        AND ST_DWithin(
            m.location,
            ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)::geography,
            max_distance_km * 1000
        )
    ORDER BY s.embedding <=> query_embedding
    LIMIT match_limit;
$$;
