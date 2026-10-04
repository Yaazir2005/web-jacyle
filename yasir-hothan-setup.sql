-- Yasir & Hothan: isku xirka labada telefoon
-- Ku dheji Supabase -> SQL Editor -> New query, kadib riix Run

create table if not exists public.yh_items (
  code_hash  text        not null,                 -- koodka (hash), ma aha koodka dhabta ah
  id         text        not null,
  data       jsonb       not null default '{}',
  deleted    boolean     not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (code_hash, id)
);

alter table public.yh_items enable row level security;
revoke all on public.yh_items from anon, authenticated;   -- shaxda toos looma gaari karo

-- soo qaad isbeddelada cusub ee koodkan
create or replace function public.yh_pull(h text, since timestamptz)
returns table(id text, data jsonb, deleted boolean, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select i.id, i.data, i.deleted, i.updated_at
  from public.yh_items i
  where i.code_hash = h and i.updated_at > since
  order by i.updated_at
  limit 50
$$;

-- kaydi isbeddelada
create or replace function public.yh_push(h text, items jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare x jsonb;
begin
  if length(h) < 8 then raise exception 'bad code'; end if;
  for x in select * from jsonb_array_elements(items) loop
    insert into public.yh_items (code_hash, id, data, deleted, updated_at)
    values (h, x->>'id', coalesce(x->'data', '{}'::jsonb),
            coalesce((x->>'deleted')::boolean, false), clock_timestamp())
    on conflict (code_hash, id) do update
      set data = excluded.data, deleted = excluded.deleted, updated_at = excluded.updated_at;
  end loop;
end $$;

grant execute on function public.yh_pull(text, timestamptz) to anon, authenticated;
grant execute on function public.yh_push(text, jsonb) to anon, authenticated;
