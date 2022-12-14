create table dec05 (
	id integer generated by default as identity,
	puzzle_input text
);

-- COPY the text into the appropriate columns
\COPY dec05 (puzzle_input) FROM input_05.txt NULL '';

select * from dec05;

-- Just starting to work out how to take the
-- first few lines and create the arrays out of it
select  array[
				string_agg(col1,null) FILTER (WHERE col1 is not null),
				string_agg(col2,null) FILTER (WHERE col2 is not null),
				string_agg(col3,null) FILTER (WHERE col3 is not null),
				string_agg(col4,null) FILTER (WHERE col4 is not null),
				string_agg(col5,null) FILTER (WHERE col5 is not null),
				string_agg(col6,null) FILTER (WHERE col6 is not null),
				string_agg(col7,null) FILTER (WHERE col7 is not null),
				string_agg(col8,null) FILTER (WHERE col8 is not null),
				string_agg(col9,null) FILTER (WHERE col9 is not null)] s
		from (
			select id,
				nullif(substr(puzzle_input,2,1),' ') col1,
				nullif(substr(puzzle_input,6,1),' ') col2,
				nullif(substr(puzzle_input,10,1),' ') col3,
				nullif(substr(puzzle_input,14,1),' ') col4,
				nullif(substr(puzzle_input,18,1),' ') col5,
				nullif(substr(puzzle_input,22,1),' ') col6,
				nullif(substr(puzzle_input,26,1),' ') col7,
				nullif(substr(puzzle_input,30,1),' ') col8,
				nullif(substr(puzzle_input,34,1),' ') col9
			from dec05
			where id <=8
		) x

-- Can we trim that down at all?
with stacks as (
	select  array[
				trim(string_agg(substr(puzzle_input,2,1),null)),
				trim(string_agg(substr(puzzle_input,6,1),null)),
				trim(string_agg(substr(puzzle_input,10,1),null)),
				trim(string_agg(substr(puzzle_input,14,1),null)),
				trim(string_agg(substr(puzzle_input,18,1),null)),
				trim(string_agg(substr(puzzle_input,22,1),null)),
				trim(string_agg(substr(puzzle_input,26,1),null)),
				trim(string_agg(substr(puzzle_input,30,1),null)),
				trim(string_agg(substr(puzzle_input,34,1),null))] s
		from dec05
			where id <=8
)
select * from stacks;


-- Now let's begin working on the rest of the puzzle
with recursive stacks as (
	select  array[
				trim(string_agg(substr(puzzle_input,2,1),null)),
				trim(string_agg(substr(puzzle_input,6,1),null)),
				trim(string_agg(substr(puzzle_input,10,1),null)),
				trim(string_agg(substr(puzzle_input,14,1),null)),
				trim(string_agg(substr(puzzle_input,18,1),null)),
				trim(string_agg(substr(puzzle_input,22,1),null)),
				trim(string_agg(substr(puzzle_input,26,1),null)),
				trim(string_agg(substr(puzzle_input,30,1),null)),
				trim(string_agg(substr(puzzle_input,34,1),null))] s
		from dec05
			where id <=8
),
moves as (
	select id,
		t[1]::int boxes,
		t[2]::int src,
		t[3]::int dest
	from dec05, regexp_match(puzzle_input,'^move ([\d]+) from ([\d]+) to ([\d]+)') as t
),
game as (
	-- This sets the recursive table up with the 
	-- appropriate columns. Started at 11 here because
	-- I know that's where the ID starts in the rows. Could
	-- clean up with a row_number() call in the previous CTE
	select 11 id, 0 boxes, 0 src, 0 dest, s stack_state
	from stacks	
	union all
	select id+1, m.boxes, m.src, m.dest, g.stack_state
	from game
		join moves m using (id)
	cross join lateral ( 
		select array_agg(si)
		from (
			select 'state' grp, 
			case when o = m.dest then
				-- notice that we reference the array here because this
				-- isn't a true table that we can move around in at this point
				--(select reverse(substr(stack_state[m.src],1,m.boxes))) || i  --star 1
				(select substr(stack_state[m.src],1,m.boxes)) || i  --star 2
			when o = m.src THEN 
				substr(i,m.boxes+1)
			else i end si
			from unnest(stack_state) with ordinality as t(i,o)
		) x
		group by x.grp
	) g(stack_state)
),
final_move as (
	-- get the last set row from the recursive query
	select * from game order by id desc limit 1
)
-- final selection of just the first letter of each guess
-- from the unnested final guess
select string_agg(first_letter,null) from 
(
	 select substr(unnest(stack_state),1,1) first_letter 
	 from final_move
) r;


