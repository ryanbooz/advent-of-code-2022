create table dec06 (
	id integer generated by default as identity,
	signal text
);

-- COPY the text into the appropriate columns
\COPY dec06 (signal) FROM input_06.txt NULL '';

-- Star 1
with recursive test as (
	select signal from dec06
),
tuning as (
	select 1 pos, 4 end_pos, string_to_array(substr(signal,1,4),null) packet from test
	union all
	select pos + 1, end_pos + 1, string_to_array(substr(signal,pos+1,4),null) packet
	from tuning, test
	where pos < length(signal)
)
select end_pos
from tuning, unnest(packet) l
group by pos, end_pos, packet
having count(distinct l) = 4
order by pos
limit 1;


-- Star 2
with recursive test as (
	select signal from dec06
),
tuning as (
	select 1 pos, 14 end_pos, STRING_TO_ARRAY(substr(signal,1,14),null) packet from test
	union all
	select pos + 1, end_pos + 1, string_to_array(substr(signal,pos+1,14),null) packet
	from tuning, test
	where pos < length(signal)
)
select end_pos
from tuning, unnest(packet) l
group by pos, end_pos, packet
having count(distinct l) = 14
order by pos
limit 1;
