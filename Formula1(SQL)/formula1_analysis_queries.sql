-- Query for top_driver_performance
SELECT s.year, d.surname, SUM(ds.points) as points
    FROM driver_standings ds
    JOIN drivers d ON ds.driverId = d.driverId
    JOIN races r ON ds.raceId = r.raceId
    JOIN seasons s ON r.year = s.year
    GROUP BY s.year, d.surname
    ORDER BY s.year, points DESC;

-- Query for constructor_performance
SELECT s.year, c.name AS constructor_name, SUM(cs.points) AS points
    FROM constructor_standings cs
    JOIN constructors c ON cs.constructorId = c.constructorId
    JOIN races r ON cs.raceId = r.raceId
    JOIN seasons s ON r.year = s.year
    GROUP BY s.year, constructor_name
    ORDER BY s.year, points DESC;

-- Query for qualifying_vs_race_results
SELECT d.surname, q.raceId, q.position AS qualifying_position, r.positionOrder AS race_position
    FROM qualifying q
    JOIN results r ON q.raceId = r.raceId AND q.driverId = r.driverId AND q.constructorId = r.constructorId
    JOIN drivers d ON q.driverId = d.driverId;

-- Query for pitstop_impact_on_results
SELECT d.surname, p.raceId, SUM(CAST(p.duration AS FLOAT)) AS duration, r.positionOrder
    FROM pitstops p
    JOIN results r ON p.raceId = r.raceId AND p.driverId = r.driverId
    JOIN drivers d ON p.driverId = d.driverId
    GROUP BY d.surname, p.raceId, r.positionOrder;

-- CTE/Window Function Query: avg_pitstop_rank_per_season
WITH pitstop_durations AS (
        SELECT 
            p.driverId, 
            r.year, 
            CAST(p.duration AS FLOAT) AS duration
        FROM pitstops p
        JOIN races r ON p.raceId = r.raceId
        WHERE p.duration IS NOT NULL
    ),
    avg_duration AS (
        SELECT 
            driverId, 
            year, 
            AVG(duration) AS avg_pit_duration
        FROM pitstop_durations
        GROUP BY driverId, year
    )
    SELECT 
        d.surname, 
        a.year, 
        a.avg_pit_duration,
        RANK() OVER (PARTITION BY a.year ORDER BY a.avg_pit_duration ASC) AS rank
    FROM avg_duration a
    JOIN drivers d ON a.driverId = d.driverId
    ORDER BY a.year, rank;

-- CTE/Window Function Query: most_consistent_qualifiers
WITH qual_variance AS (
        SELECT 
            q.driverId,
            d.surname,
            COUNT(q.raceId) AS total_races,
            AVG(q.position) AS avg_qual_pos,
            STDDEV(q.position) OVER (PARTITION BY q.driverId) AS stddev_qual_pos
        FROM qualifying q
        JOIN drivers d ON q.driverId = d.driverId
        GROUP BY q.driverId
    )
    SELECT *
    FROM qual_variance
    WHERE total_races >= 10
    ORDER BY stddev_qual_pos ASC;

-- CTE/Window Function Query: points_gap_between_drivers
WITH yearly_points AS (
        SELECT 
            r.year, 
            d.driverId, 
            d.surname, 
            SUM(ds.points) AS total_points
        FROM driver_standings ds
        JOIN races r ON ds.raceId = r.raceId
        JOIN drivers d ON ds.driverId = d.driverId
        GROUP BY r.year, d.driverId
    ),
    ranked_points AS (
        SELECT *,
               RANK() OVER (PARTITION BY year ORDER BY total_points DESC) AS rank
        FROM yearly_points
    )
    SELECT 
        year, 
        surname, 
        total_points,
        rank,
        total_points - LAG(total_points) OVER (PARTITION BY year ORDER BY total_points DESC) AS point_gap_from_previous
    FROM ranked_points
    WHERE rank <= 5
    ORDER BY year, rank;

-- Advanced Query with CTE/Window: driver_position_trend
WITH race_positions AS (
        SELECT 
            r.year, 
            d.driverId, 
            d.surname, 
            r.raceId, 
            re.positionOrder,
            ROW_NUMBER() OVER (PARTITION BY r.year, d.driverId ORDER BY r.round) AS race_num
        FROM results re
        JOIN races r ON re.raceId = r.raceId
        JOIN drivers d ON re.driverId = d.driverId
        WHERE re.positionOrder IS NOT NULL
    )
    SELECT *
    FROM race_positions
    WHERE driverId IN (
        SELECT driverId 
        FROM results 
        GROUP BY driverId 
        HAVING COUNT(*) > 50
    )
    ORDER BY driverId, race_num;

-- Advanced Query with CTE/Window: constructor_domination_streaks
WITH constructor_wins AS (
        SELECT 
            r.year, 
            r.round, 
            c.name AS constructor_name, 
            re.positionOrder,
            ROW_NUMBER() OVER (PARTITION BY r.year ORDER BY r.round) AS race_index
        FROM results re
        JOIN races r ON re.raceId = r.raceId
        JOIN constructors c ON re.constructorId = c.constructorId
        WHERE re.positionOrder = 1
    ),
    win_streaks AS (
        SELECT 
            year, 
            constructor_name, 
            COUNT(*) AS wins
        FROM constructor_wins
        GROUP BY year, constructor_name
        HAVING COUNT(*) > 3
    )
    SELECT * FROM win_streaks
    ORDER BY year, wins DESC;

-- Advanced Query with CTE/Window: fastest_lap_vs_finish
WITH fastest_laps AS (
        SELECT 
            l.raceId,
            l.driverId,
            MIN(l.milliseconds) AS fastest_lap_time
        FROM laptimes l
        GROUP BY l.raceId
    ),
    driver_lap_times AS (
        SELECT 
            f.raceId,
            d.surname,
            r.positionOrder,
            f.fastest_lap_time
        FROM fastest_laps f
        JOIN results r ON f.raceId = r.raceId AND f.driverId = r.driverId
        JOIN drivers d ON r.driverId = d.driverId
    )
    SELECT *
    FROM driver_lap_times
    WHERE positionOrder IS NOT NULL
    ORDER BY raceId;

