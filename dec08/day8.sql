/**************************
 * Star 1
 **************************/

/*
 * Using test data from puzzle:
 * 
 * This first attempt proved to be off because I didn't
 * fully read the puzzle instructions. This only finds
 * trees that are hidden by the tress directly around
 * it. 🤦‍♂️ 
 * 
 * Instead, a tree is visible if all trees on either side
 * (both horizontal and vertical) are shorter. Oops! 
 */
-- Let's build up what I was trying to do.

-- To get the numbers into an array of numbers, they had to be split
-- into a string first, and then group them again. There is no "split_to_array"
SELECT STRING_TO_ARRAY('30373',null);

-- This is an array of strings, however. We can cast it for later
SELECT STRING_TO_ARRAY('30373',null)::int[];

-- One last alternative. More, generally unecessary work, but will
-- be handy in our actual solution.
SELECT string_to_table('30373',null);

-- know the position of each integer in the string for later comparison
SELECT * FROM string_to_table('30373',null)
WITH ORDINALITY AS t(i,o);

-- if we still wanted to get it back to an array, we can aggregate. 
-- Again, this is basically needless work, but can be helpful during
-- exploration.
SELECT array_agg(i) FROM ( 
	SELECT * FROM string_to_table('30373',null)
	WITH ORDINALITY AS t(i,o)
	ORDER BY o desc
) x;


-- Get all rows from tex to arrays of integers
with recursive s as (select a from (values
('30373'),
('25512'),
('65332'),
('33549'),
('35390')) as t(a)
),
matrix as (
	select row_number() over() id, string_to_array(a,null)::int[] tree_row FROM s 
)
--select * from matrix;
,
mc as (
	select id, null::int[] prev, tree_row curr, (select tree_row from matrix where id = 2) nxt
 	from matrix where id = 1
 	--
	union all
	--
	select m.id, y.prev, m.tree_row curr, y.nxt 
	from matrix m
	join mc on m.id = mc.id+1
	cross join lateral (
		select 
			(select tree_row from matrix where id = m.id-1) prev,
			(select tree_row from matrix where id = m.id+1) nxt
		)y
)
--select * from mc;
--,unnest(curr) WITH ORDINALITY t(i,o);
,
mnest as (
	SELECT mc.*, t.o, 
	CASE WHEN prev IS NULL OR nxt IS NULL THEN 1
		WHEN o = 1 OR o = cardinality(curr) THEN 1
		WHEN (prev[o] <= curr[o] OR curr[o-1] <= curr[o] OR curr[o+1] <= curr[o] OR nxt[o] <= curr[o]) THEN 1
		ELSE 0
		END visible
	FROM mc,
	unnest(curr) WITH ORDINALITY t(i,o)
)
SELECT * FROM mnest;


/*
 * Second attempt know that I understand. Essentially,
 * get a grid and "look", item by item, in each direction
 * to see if any other trees are taller. If not, they are
 * "visible"
 */
--SET jit=ON;
--EXPLAIN analyze
with s as (select a from (values
('30373'),
('25512'),
('65332'),
('33549'),
('35390')) as t(a)
),
grid as (
	select row_number() over() id, a::text from s
),
trees AS (
    SELECT t.o as x,
           d.id as y,
           t.tree::int
    FROM grid AS d
    CROSS JOIN string_to_table(a, NULL) WITH ORDINALITY AS t (tree, o)
)
--select * from trees;
select sum(visible) from (
	select m.x, m.y, tree, 
		case when m.y = maxh.miny or m.y = maxh.maxy then 1
		when m.x = maxh.minx or m.x = maxh.maxx then 1  
		when tree > (select max(tree) from trees where x < m.x and y=m.y) then 1
		when tree > (select max(tree) from trees where x > m.x and y = m.y) then 1
		when tree > (select max(tree) from trees where y < m.y and x = m.x) then 1
		when tree > (select max(tree) from trees where y > m.y and x = m.x) then 1
		else 0 end visible
	from trees m
	CROSS JOIN
		(select min(x), max(x), min(y), max(y) FROM trees) AS maxh(minx, maxx, miny, maxy)
) j;


/*
 * Real data
 */

drop table dec08;

create table dec08 (
	id integer generated by default as identity,
	trees text
);

-- COPY the text into the appropriate columns
\COPY dec08 (trees) FROM input_08.txt NULL '';

select * from dec08;

/**************************
 * Star 1
 **************************/
--EXPLAIN analyze
with trees (x, y, tree) AS (
    SELECT t.o,
           d.id,
           t.tree::int
    FROM dec08 AS d
    CROSS JOIN string_to_table(trees, NULL) WITH ORDINALITY AS t (tree, o)
)
select sum(visible) from (
	select m.x, m.y, tree, 
		case when m.y = maxh.miny or m.y = maxh.maxy then 1
		when m.x = maxh.minx or m.x = maxh.maxx then 1 
		when tree > (select max(tree) from trees where x < m.x and y = m.y) then 1
		when tree > (select max(tree) from trees where x > m.x and y = m.y) then 1
		when tree > (select max(tree) from trees where y < m.y and x = m.x) then 1
		when tree > (select max(tree) from trees where y > m.y and x = m.x) then 1
		else 0 end visible
	from trees m
	CROSS JOIN
		(select min(x), max(x), min(y), max(y) FROM trees) AS maxh(minx, maxx, miny, maxy)
) j;

-- Does turning off JIT help here too?
--SET jit=off;

/*
 * A better, significantly faster version courtesy of
 * Vik Fearing. Nothing like a simple window function
 * to solve the problem.
 */
with trees (x, y, tree) AS (
    SELECT t.o,
           d.id,
           t.tree::int
    FROM dec08 AS d
    CROSS JOIN string_to_table(trees, NULL) WITH ORDINALITY AS t (tree, o)
)
select count(*) from (
	select x, y, tree, 
			tree > COALESCE(MAX(tree) OVER from_north, -1) or
	        tree > COALESCE(MAX(tree) OVER from_east,  -1) or
	        tree > COALESCE(MAX(tree) OVER from_south, -1) or
	        tree > COALESCE(MAX(tree) OVER from_west,  -1) as visible
	FROM trees
	WINDOW from_north AS (PARTITION BY x ORDER BY y ASC  ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW),
	       from_east  AS (PARTITION BY y ORDER BY x DESC ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW),
	       from_south AS (PARTITION BY x ORDER BY y DESC ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW),
	       from_west  AS (PARTITION BY y ORDER BY x ASC  ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW)
	) j
where visible;



/**************************
 * Star 2
 **************************/
with trees (x, y, tree) AS (
    SELECT t.o,
           d.id,
           t.tree::int
    FROM dec08 AS d
    CROSS JOIN string_to_table(trees, NULL) WITH ORDINALITY AS t (tree, o)
)
select x,y,tree,(ut*dt*lt*rt) scenic_score from (
	select x,y,tree, (y-u) ut,(d-y) dt,(x-l) lt,(r-x) rt from (
	select m.x, m.y, tree, 
		(select COALESCE(max(y),1) from trees where y < m.y and x = m.x and tree >= m.tree) u, --up
		(select COALESCE(min(y),maxh.y) from trees where y > m.y and x = m.x and tree >= m.tree) d, --down
		(select COALESCE(max(x),1) from trees where x < m.x and y = m.y and tree >= m.tree) l, --left
		(select COALESCE(min(x),maxh.x) from trees where x > m.x and y = m.y and tree >= m.tree) r --right
	from trees m
	CROSS JOIN LATERAL -- dynamically find LAST ROW AND LAST COLUMN FOR the INPUT DATA set
		(select 
		(select x from trees order by x desc limit 1),
		(select y from trees order by y desc limit 1)) AS maxh(x,y)
	) j
) p
order by scenic_score desc;









