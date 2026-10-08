-- JenaCraft Collaborative Mindmap · Supabase schema
-- Im Supabase SQL Editor vollständig ausführen.
-- Enthält sichere RPC-Funktionen sowie „Auf Vorlage zurücksetzen“.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.mm_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text unique not null,
  title text not null check (char_length(title) between 1 and 120),
  template_key text not null default 'custom',
  moderator_secret_hash text not null,
  is_open boolean not null default true,
  collected_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.mm_branches (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references public.mm_sessions(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  sort_order int not null default 0
);

create table if not exists public.mm_nodes (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references public.mm_sessions(id) on delete cascade,
  group_no int not null check (group_no between 1 and 99),
  branch_id uuid not null references public.mm_branches(id) on delete cascade,
  parent_id uuid references public.mm_nodes(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 240),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mm_nodes_session_idx on public.mm_nodes(session_id);
create index if not exists mm_nodes_group_idx on public.mm_nodes(session_id, group_no);

-- Diese Erweiterungen sind auch auf einer bereits vorhandenen Workshop-Datenbank
-- erneut ausführbar und verändern keine bestehenden Inhalte.
alter table public.mm_sessions
  add column if not exists participants_can_export boolean not null default false,
  add column if not exists root_position text not null default 'left',
  add column if not exists root_orientation text not null default 'horizontal';

alter table public.mm_branches
  add column if not exists color text not null default '#eef8c9',
  add column if not exists layout_x double precision,
  add column if not exists layout_y double precision,
  add column if not exists bend_x double precision,
  add column if not exists bend_y double precision;

alter table public.mm_nodes
  add column if not exists layout_x double precision,
  add column if not exists layout_y double precision,
  add column if not exists bend_x double precision,
  add column if not exists bend_y double precision;

-- Gruppe 0 kennzeichnet Beiträge des Referenten. Gruppen 1–99 bleiben für
-- Teilnehmende reserviert; vorhandene Beiträge bleiben unverändert gültig.
do $$
declare group_constraint text;
begin
  select conname into group_constraint
    from pg_constraint
    where conrelid='public.mm_nodes'::regclass and conname='mm_nodes_group_no_check';
  if group_constraint is not null then
    execute format('alter table public.mm_nodes drop constraint %I', group_constraint);
  end if;
  alter table public.mm_nodes add constraint mm_nodes_group_no_check
    check (group_no between 0 and 99);
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='mm_sessions_root_position_check') then
    alter table public.mm_sessions add constraint mm_sessions_root_position_check
      check (root_position in ('left','right','top','bottom','center'));
  end if;
  if not exists (select 1 from pg_constraint where conname='mm_sessions_root_orientation_check') then
    alter table public.mm_sessions add constraint mm_sessions_root_orientation_check
      check (root_orientation in ('horizontal','vertical'));
  end if;
end $$;

alter table public.mm_sessions enable row level security;
alter table public.mm_branches enable row level security;
alter table public.mm_nodes enable row level security;

revoke all on public.mm_sessions from anon, authenticated;
revoke all on public.mm_branches from anon, authenticated;
revoke all on public.mm_nodes from anon, authenticated;

create or replace function public.mm_make_code()
returns text
language plpgsql
security definer
set search_path=public, extensions
as $$
declare c text;
begin
  loop
    c := upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,6));
    exit when not exists(select 1 from public.mm_sessions where code=c);
  end loop;
  return c;
end $$;

create or replace function public.mm_token_ok(p_session_id uuid, p_token text)
returns boolean
language sql
stable
security definer
set search_path=public, extensions
as $$
  select exists(
    select 1 from public.mm_sessions
    where id=p_session_id
      and moderator_secret_hash = encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex')
  );
$$;

create or replace function public.create_session(p_title text, p_template_key text, p_branch_titles text[])
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions; tok text; b text; i int:=0;
begin
  if p_title is null or btrim(p_title)='' then raise exception 'Titel fehlt'; end if;
  if array_length(p_branch_titles,1) is null then raise exception 'Mindestens ein Ast wird benötigt'; end if;
  tok := encode(extensions.gen_random_bytes(24),'hex');
  insert into public.mm_sessions(code,title,template_key,moderator_secret_hash)
  values(
    public.mm_make_code(),
    left(btrim(p_title),120),
    coalesce(nullif(p_template_key,''),'custom'),
    encode(extensions.digest(tok,'sha256'),'hex')
  ) returning * into s;
  foreach b in array p_branch_titles loop
    if btrim(b)<>'' then
      insert into public.mm_branches(session_id,title,sort_order)
      values(s.id,left(btrim(b),80),i);
      i:=i+1;
    end if;
  end loop;
  return jsonb_build_object(
    'session',jsonb_build_object(
      'id',s.id,'code',s.code,'title',s.title,'is_open',s.is_open,'created_at',s.created_at,
      'participants_can_export',s.participants_can_export,
      'root_position',s.root_position,
      'root_orientation',s.root_orientation
    ),
    'moderator_token',tok
  );
end $$;

create or replace function public.get_session_public(p_code text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found then return null; end if;
  return jsonb_build_object(
    'session',jsonb_build_object('id',s.id,'code',s.code,'title',s.title,'is_open',s.is_open,'created_at',s.created_at),
    'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'sort_order',sort_order,'color',color,'layout_x',layout_x,'layout_y',layout_y,'bend_x',bend_x,'bend_y',bend_y) order by sort_order) from public.mm_branches where session_id=s.id),'[]'::jsonb)
  );
end $$;

create or replace function public.get_group_nodes(p_code text,p_group_no int)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare sid uuid;
begin
  select id into sid from public.mm_sessions where code=upper(btrim(p_code));
  if sid is null then raise exception 'Session nicht gefunden'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',id,'branch_id',branch_id,'parent_id',parent_id,'group_no',group_no,
      'text',text,'created_at',created_at,'updated_at',updated_at,
      'layout_x',layout_x,'layout_y',layout_y,'bend_x',bend_x,'bend_y',bend_y
    ) order by created_at)
    from public.mm_nodes where session_id=sid and group_no=p_group_no
  ),'[]'::jsonb);
end $$;

create or replace function public.add_node(p_code text,p_group_no int,p_branch_id uuid,p_parent_id uuid,p_text text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions; n public.mm_nodes;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found then raise exception 'Session nicht gefunden'; end if;
  if not s.is_open then raise exception 'Die Session ist gesperrt'; end if;
  if p_group_no<1 or p_group_no>99 then raise exception 'Ungültige Gruppe'; end if;
  if p_text is null or btrim(p_text)='' then raise exception 'Text fehlt'; end if;
  if not exists(select 1 from public.mm_branches where id=p_branch_id and session_id=s.id) then raise exception 'Ungültiger Ast'; end if;
  if p_parent_id is not null and not exists(
    select 1 from public.mm_nodes
    where id=p_parent_id and session_id=s.id and group_no=p_group_no and branch_id=p_branch_id
  ) then raise exception 'Ungültiger Elternknoten'; end if;
  insert into public.mm_nodes(session_id,group_no,branch_id,parent_id,text)
  values(s.id,p_group_no,p_branch_id,p_parent_id,left(btrim(p_text),240)) returning * into n;
  return to_jsonb(n);
end $$;

create or replace function public.update_node(p_code text,p_group_no int,p_node_id uuid,p_text text)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare sid uuid; open_state boolean;
begin
  select id,is_open into sid,open_state from public.mm_sessions where code=upper(btrim(p_code));
  if sid is null then raise exception 'Session nicht gefunden'; end if;
  if not open_state then raise exception 'Session nicht offen'; end if;
  if p_text is null or btrim(p_text)='' then raise exception 'Text fehlt'; end if;
  update public.mm_nodes set text=left(btrim(p_text),240),updated_at=now()
  where id=p_node_id and session_id=sid and group_no=p_group_no;
  if not found then raise exception 'Knoten nicht gefunden'; end if;
end $$;

create or replace function public.delete_node(p_code text,p_group_no int,p_node_id uuid)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare sid uuid; open_state boolean;
begin
  select id,is_open into sid,open_state from public.mm_sessions where code=upper(btrim(p_code));
  if sid is null then raise exception 'Session nicht gefunden'; end if;
  if not open_state then raise exception 'Session nicht offen'; end if;
  delete from public.mm_nodes where id=p_node_id and session_id=sid and group_no=p_group_no;
  if not found then raise exception 'Knoten nicht gefunden'; end if;
end $$;

create or replace function public.moderator_snapshot(p_code text,p_moderator_token text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  return jsonb_build_object(
    'session',jsonb_build_object(
      'id',s.id,'code',s.code,'title',s.title,'template_key',s.template_key,
      'is_open',s.is_open,'collected_at',s.collected_at,'created_at',s.created_at,
      'participants_can_export',s.participants_can_export,
      'root_position',s.root_position,'root_orientation',s.root_orientation
    ),
    'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'sort_order',sort_order,'color',color,'layout_x',layout_x,'layout_y',layout_y,'bend_x',bend_x,'bend_y',bend_y) order by sort_order) from public.mm_branches where session_id=s.id),'[]'::jsonb),
    'nodes',coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,'branch_id',branch_id,'parent_id',parent_id,'group_no',group_no,
      'text',text,'created_at',created_at,'updated_at',updated_at,
      'layout_x',layout_x,'layout_y',layout_y,'bend_x',bend_x,'bend_y',bend_y
    ) order by created_at) from public.mm_nodes where session_id=s.id),'[]'::jsonb)
  );
end $$;

create or replace function public.update_branch_color(
  p_code text,
  p_moderator_token text,
  p_branch_id uuid,
  p_color text
)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then
    raise exception 'Moderator-Zugriff verweigert';
  end if;
  if p_color !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Ungültige Astfarbe'; end if;
  update public.mm_branches set color=lower(p_color) where id=p_branch_id and session_id=s.id;
  if not found then raise exception 'Ast nicht gefunden'; end if;
end $$;

create or replace function public.moderator_add_branch(
  p_code text,
  p_moderator_token text,
  p_title text
)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions; b public.mm_branches;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  if p_title is null or btrim(p_title)='' then raise exception 'Asttitel fehlt'; end if;
  insert into public.mm_branches(session_id,title,sort_order)
  values(s.id,left(btrim(p_title),80),coalesce((select max(sort_order)+1 from public.mm_branches where session_id=s.id),0))
  returning * into b;
  return jsonb_build_object('id',b.id,'title',b.title,'sort_order',b.sort_order,'color',b.color);
end $$;

create or replace function public.moderator_add_node(
  p_code text,
  p_moderator_token text,
  p_branch_id uuid,
  p_parent_id uuid,
  p_text text
)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions; n public.mm_nodes;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  if p_text is null or btrim(p_text)='' then raise exception 'Text fehlt'; end if;
  if not exists(select 1 from public.mm_branches where id=p_branch_id and session_id=s.id) then raise exception 'Ungültiger Ast'; end if;
  if p_parent_id is not null and not exists(select 1 from public.mm_nodes where id=p_parent_id and session_id=s.id and branch_id=p_branch_id) then raise exception 'Ungültiger Elternknoten'; end if;
  insert into public.mm_nodes(session_id,group_no,branch_id,parent_id,text)
  values(s.id,0,p_branch_id,p_parent_id,left(btrim(p_text),240))
  returning * into n;
  return to_jsonb(n);
end $$;

create or replace function public.moderator_update_node(
  p_code text,
  p_moderator_token text,
  p_node_id uuid,
  p_text text
)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  if p_text is null or btrim(p_text)='' then raise exception 'Text fehlt'; end if;
  update public.mm_nodes set text=left(btrim(p_text),240),updated_at=now() where id=p_node_id and session_id=s.id;
  if not found then raise exception 'Knoten nicht gefunden'; end if;
end $$;

create or replace function public.moderator_move_node(
  p_code text,
  p_moderator_token text,
  p_node_id uuid,
  p_target_branch_id uuid
)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  if not exists(select 1 from public.mm_branches where id=p_target_branch_id and session_id=s.id) then raise exception 'Zielast nicht gefunden'; end if;
  if not exists(select 1 from public.mm_nodes where id=p_node_id and session_id=s.id) then raise exception 'Knoten nicht gefunden'; end if;
  with recursive subtree as (
    select id from public.mm_nodes where id=p_node_id and session_id=s.id
    union all
    select child.id from public.mm_nodes child join subtree tree on child.parent_id=tree.id where child.session_id=s.id
  )
  update public.mm_nodes
    set branch_id=p_target_branch_id,
        parent_id=case when id=p_node_id then null else parent_id end,
        updated_at=now()
    where id in (select id from subtree);
end $$;

create or replace function public.update_layout_item(
  p_code text, p_moderator_token text, p_kind text, p_id uuid, p_x double precision, p_y double precision
)
returns void language plpgsql security definer set search_path=public, extensions as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  if p_x is null or p_y is null or abs(p_x)>10000 or abs(p_y)>10000 then raise exception 'Ungültige Position'; end if;
  if p_kind='branch' then update public.mm_branches set layout_x=p_x,layout_y=p_y where id=p_id and session_id=s.id;
  elsif p_kind='node' then update public.mm_nodes set layout_x=p_x,layout_y=p_y,updated_at=now() where id=p_id and session_id=s.id;
  else raise exception 'Ungültiger Layouttyp'; end if;
  if not found then raise exception 'Layoutobjekt nicht gefunden'; end if;
end $$;

create or replace function public.update_layout_bend(
  p_code text, p_moderator_token text, p_kind text, p_id uuid, p_x double precision, p_y double precision
)
returns void language plpgsql security definer set search_path=public, extensions as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  if p_x is null or p_y is null or abs(p_x)>10000 or abs(p_y)>10000 then raise exception 'Ungültiger Knickpunkt'; end if;
  if p_kind='branch' then update public.mm_branches set bend_x=p_x,bend_y=p_y where id=p_id and session_id=s.id;
  elsif p_kind='node' then update public.mm_nodes set bend_x=p_x,bend_y=p_y,updated_at=now() where id=p_id and session_id=s.id;
  else raise exception 'Ungültiger Layouttyp'; end if;
  if not found then raise exception 'Verbindung nicht gefunden'; end if;
end $$;

create or replace function public.moderator_reparent_node(
  p_code text, p_moderator_token text, p_node_id uuid, p_target_parent_id uuid
)
returns void language plpgsql security definer set search_path=public, extensions as $$
declare s public.mm_sessions; target public.mm_nodes;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  select * into target from public.mm_nodes where id=p_target_parent_id and session_id=s.id;
  if not found then raise exception 'Zielknoten nicht gefunden'; end if;
  if p_node_id=p_target_parent_id then raise exception 'Ein Knoten kann nicht sein eigener Elternknoten sein'; end if;
  if exists(with recursive subtree as (select id from public.mm_nodes where id=p_node_id and session_id=s.id union all select child.id from public.mm_nodes child join subtree tree on child.parent_id=tree.id) select 1 from subtree where id=p_target_parent_id) then raise exception 'Ein Knoten kann nicht in seine eigene Teilast verschoben werden'; end if;
  if not exists(select 1 from public.mm_nodes where id=p_node_id and session_id=s.id) then raise exception 'Knoten nicht gefunden'; end if;
  with recursive subtree as (
    select id from public.mm_nodes where id=p_node_id and session_id=s.id
    union all select child.id from public.mm_nodes child join subtree tree on child.parent_id=tree.id
  )
  update public.mm_nodes set branch_id=target.branch_id, parent_id=case when id=p_node_id then target.id else parent_id end, updated_at=now() where id in (select id from subtree);
end $$;

create or replace function public.moderator_delete_node(
  p_code text, p_moderator_token text, p_node_id uuid
)
returns void language plpgsql security definer set search_path=public, extensions as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  delete from public.mm_nodes where id=p_node_id and session_id=s.id;
  if not found then raise exception 'Knoten nicht gefunden'; end if;
end $$;

-- Ausschließlich der Moderator einer Session darf Darstellungs- und Exportrechte ändern.
create or replace function public.update_session_settings(
  p_code text,
  p_moderator_token text,
  p_root_position text,
  p_root_orientation text,
  p_participants_can_export boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then
    raise exception 'Moderator-Zugriff verweigert';
  end if;
  if p_root_position not in ('left','right','top','bottom','center') then
    raise exception 'Ungültige Root-Position';
  end if;
  if p_root_orientation not in ('horizontal','vertical') then
    raise exception 'Ungültige Titelorientierung';
  end if;
  -- Changing the base layout restores the clean automatic arrangement and
  -- removes manual positions and line bends saved for the old orientation.
  if s.root_position is distinct from p_root_position
     or s.root_orientation is distinct from p_root_orientation then
    update public.mm_branches
      set layout_x=null, layout_y=null, bend_x=null, bend_y=null
      where session_id=s.id;
    update public.mm_nodes
      set layout_x=null, layout_y=null, bend_x=null, bend_y=null
      where session_id=s.id;
  end if;
  update public.mm_sessions
    set root_position=p_root_position,
        root_orientation=p_root_orientation,
        participants_can_export=coalesce(p_participants_can_export,false)
    where id=s.id
    returning * into s;
  return jsonb_build_object(
    'root_position',s.root_position,
    'root_orientation',s.root_orientation,
    'participants_can_export',s.participants_can_export
  );
end $$;

create or replace function public.set_session_open(p_code text,p_moderator_token text,p_is_open boolean)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  update public.mm_sessions set is_open=p_is_open where id=s.id;
end $$;

create or replace function public.mark_collected(p_code text,p_moderator_token text)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  update public.mm_sessions set collected_at=now() where id=s.id;
end $$;

-- Setzt die Session auf ihre Vorlage zurück.
-- JenaCraft: Titel + vier Standardäste werden wiederhergestellt.
-- Custom: Beiträge werden gelöscht, vorhandene Aststruktur bleibt bestehen.
create or replace function public.reset_session_to_template(p_code text,p_moderator_token text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then
    raise exception 'Moderator-Zugriff verweigert';
  end if;

  -- Beiträge zuerst löschen; dadurch gibt es keine Fremdschlüsselkonflikte.
  delete from public.mm_nodes where session_id=s.id;

  if s.template_key='jenacraft' then
    delete from public.mm_branches where session_id=s.id;

    update public.mm_sessions
      set title='Must haves und No Gos JenaCraft',
          is_open=true,
          collected_at=null
      where id=s.id;

    insert into public.mm_branches(session_id,title,sort_order) values
      (s.id,'Must Haves',0),
      (s.id,'No Gos',1),
      (s.id,'Anmerkung',2),
      (s.id,'Gern besuchte Orte',3);

    return jsonb_build_object(
      'ok',true,
      'mode','jenacraft',
      'message','Beiträge gelöscht und JenaCraft-Vorlage wiederhergestellt.'
    );
  else
    update public.mm_sessions
      set is_open=true,
          collected_at=null
      where id=s.id;

    return jsonb_build_object(
      'ok',true,
      'mode','custom',
      'message','Beiträge gelöscht. Die benutzerdefinierte Aststruktur wurde beibehalten.'
    );
  end if;
end $$;

-- Browserzugriff nur auf die benötigten RPC-Funktionen.
-- Löscht ausschließlich die mit dem Moderator-Token autorisierte Session.
-- Abhängige Äste und Knoten werden durch ON DELETE CASCADE mit entfernt.
create or replace function public.delete_session(p_code text,p_moderator_token text)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  delete from public.mm_sessions where id=s.id;
end $$;

-- 30 Tage sind die zentrale Standard-Aufbewahrungsdauer. Diese Funktion wird
-- nur durch Supabase Cron ausgeführt und nie an Browserrollen freigegeben.
create or replace function public.cleanup_old_mindmap_sessions()
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare deleted_count integer;
begin
  delete from public.mm_sessions where created_at < now() - interval '30 days';
  get diagnostics deleted_count = row_count;
  return deleted_count;
end $$;

-- Stellt ein geprüftes JSON-Backup immer als neue Session wieder her. Alte IDs
-- werden nur als Mapping-Werte verwendet und niemals wiederverwendet.
create or replace function public.restore_session_from_backup(p_backup jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare
  s public.mm_sessions; tok text; mindmap jsonb; settings jsonb;
  branch_item jsonb; node_item jsonb; parent_item jsonb;
  branch_map jsonb:='{}'::jsonb; node_map jsonb:='{}'::jsonb; node_seen jsonb:='{}'::jsonb;
  legacy_id text; parent_legacy_id text; branch_legacy_id text; new_id uuid;
  item_count integer:=0; made_count integer; restored_count integer; order_index integer:=0; node_group integer;
begin
  if jsonb_typeof(p_backup)<>'object' or p_backup->>'format'<>'jenacraft-mindmap' or p_backup->>'version'<>'1' then raise exception 'Ungültiges Mindmap-Backupformat'; end if;
  mindmap:=p_backup->'mindmap'; settings:=p_backup->'settings';
  if jsonb_typeof(mindmap)<>'object' or jsonb_typeof(settings)<>'object' or jsonb_typeof(p_backup->'branches')<>'array' or jsonb_typeof(p_backup->'nodes')<>'array' then raise exception 'Unvollständiges Mindmap-Backup'; end if;
  if jsonb_typeof(mindmap->'title')<>'string' or char_length(btrim(mindmap->>'title')) not between 1 and 120 then raise exception 'Ungültiger Mindmap-Titel'; end if;
  if coalesce(mindmap->>'root_position','') not in ('left','right','top','bottom','center') or coalesce(mindmap->>'root_orientation','') not in ('horizontal','vertical') or jsonb_typeof(settings->'participants_can_export')<>'boolean' then raise exception 'Ungültige Mindmap-Einstellungen'; end if;
  if jsonb_array_length(p_backup->'branches')<1 then raise exception 'Mindestens ein Ast wird benötigt'; end if;

  tok:=encode(extensions.gen_random_bytes(24),'hex');
  insert into public.mm_sessions(code,title,template_key,moderator_secret_hash,participants_can_export,root_position,root_orientation)
  values(public.mm_make_code(),left(btrim(mindmap->>'title'),120),left(coalesce(nullif(btrim(mindmap->>'template_key'),''),'custom'),80),encode(extensions.digest(tok,'sha256'),'hex'),(settings->>'participants_can_export')::boolean,mindmap->>'root_position',mindmap->>'root_orientation') returning * into s;
  for branch_item in select value from jsonb_array_elements(p_backup->'branches') loop
    legacy_id:=branch_item->>'legacy_id';
    if jsonb_typeof(branch_item)<>'object' or legacy_id is null or char_length(legacy_id) not between 1 and 120 or branch_map ? legacy_id or jsonb_typeof(branch_item->'title')<>'string' or char_length(btrim(branch_item->>'title')) not between 1 and 80 then raise exception 'Ungültiger oder doppelter Ast im Backup'; end if;
    if branch_item ? 'color' and branch_item->>'color' is not null and branch_item->>'color' !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Ungültige Astfarbe'; end if;
    if branch_item ? 'sort_order' and (jsonb_typeof(branch_item->'sort_order')<>'number' or branch_item->>'sort_order' !~ '^[0-9]+$') then raise exception 'Ungültige Astreihenfolge'; end if;
    if (branch_item ? 'layout_x' and branch_item->>'layout_x' is not null and (jsonb_typeof(branch_item->'layout_x')<>'number' or abs((branch_item->>'layout_x')::double precision)>10000)) or (branch_item ? 'layout_y' and branch_item->>'layout_y' is not null and (jsonb_typeof(branch_item->'layout_y')<>'number' or abs((branch_item->>'layout_y')::double precision)>10000)) or (branch_item ? 'bend_x' and branch_item->>'bend_x' is not null and (jsonb_typeof(branch_item->'bend_x')<>'number' or abs((branch_item->>'bend_x')::double precision)>10000)) or (branch_item ? 'bend_y' and branch_item->>'bend_y' is not null and (jsonb_typeof(branch_item->'bend_y')<>'number' or abs((branch_item->>'bend_y')::double precision)>10000)) then raise exception 'Ungültige Astposition'; end if;
    insert into public.mm_branches(session_id,title,sort_order,color,layout_x,layout_y,bend_x,bend_y) values(s.id,btrim(branch_item->>'title'),coalesce((branch_item->>'sort_order')::int,order_index),coalesce(lower(branch_item->>'color'),'#eef8c9'),(branch_item->>'layout_x')::double precision,(branch_item->>'layout_y')::double precision,(branch_item->>'bend_x')::double precision,(branch_item->>'bend_y')::double precision) returning id into new_id;
    branch_map:=branch_map||jsonb_build_object(legacy_id,new_id::text); order_index:=order_index+1;
  end loop;
  for node_item in select value from jsonb_array_elements(p_backup->'nodes') loop
    legacy_id:=node_item->>'legacy_id'; branch_legacy_id:=node_item->>'branch_legacy_id'; parent_legacy_id:=node_item->>'legacy_parent_id';
    if jsonb_typeof(node_item)<>'object' or legacy_id is null or char_length(legacy_id) not between 1 and 120 or branch_legacy_id is null or node_seen ? legacy_id or not (branch_map ? branch_legacy_id) or jsonb_typeof(node_item->'text')<>'string' or char_length(btrim(node_item->>'text')) not between 1 and 240 or jsonb_typeof(node_item->'group_no')<>'number' or node_item->>'group_no' !~ '^[0-9]+$' then raise exception 'Ungültiger oder doppelter Knoten im Backup'; end if;
    node_group:=(node_item->>'group_no')::int; if node_group not between 0 and 99 then raise exception 'Ungültige Gruppe im Backup'; end if;
    if (node_item ? 'layout_x' and node_item->>'layout_x' is not null and (jsonb_typeof(node_item->'layout_x')<>'number' or abs((node_item->>'layout_x')::double precision)>10000)) or (node_item ? 'layout_y' and node_item->>'layout_y' is not null and (jsonb_typeof(node_item->'layout_y')<>'number' or abs((node_item->>'layout_y')::double precision)>10000)) or (node_item ? 'bend_x' and node_item->>'bend_x' is not null and (jsonb_typeof(node_item->'bend_x')<>'number' or abs((node_item->>'bend_x')::double precision)>10000)) or (node_item ? 'bend_y' and node_item->>'bend_y' is not null and (jsonb_typeof(node_item->'bend_y')<>'number' or abs((node_item->>'bend_y')::double precision)>10000)) then raise exception 'Ungültige Knotenposition'; end if;
    if parent_legacy_id is not null then
      select value into parent_item from jsonb_array_elements(p_backup->'nodes') where value->>'legacy_id'=parent_legacy_id limit 1;
      if parent_item is null or parent_item->>'branch_legacy_id'<>branch_legacy_id or parent_item->>'group_no'<>node_item->>'group_no' then raise exception 'Ungültige Elternbeziehung im Backup'; end if;
    end if;
    node_seen:=node_seen||jsonb_build_object(legacy_id,true); item_count:=item_count+1;
  end loop;
  for node_item in select value from jsonb_array_elements(p_backup->'nodes') loop
    if node_item->>'legacy_parent_id' is null then
      insert into public.mm_nodes(session_id,group_no,branch_id,parent_id,text,layout_x,layout_y,bend_x,bend_y) values(s.id,(node_item->>'group_no')::int,(branch_map->>(node_item->>'branch_legacy_id'))::uuid,null,btrim(node_item->>'text'),(node_item->>'layout_x')::double precision,(node_item->>'layout_y')::double precision,(node_item->>'bend_x')::double precision,(node_item->>'bend_y')::double precision) returning id into new_id;
      node_map:=node_map||jsonb_build_object(node_item->>'legacy_id',new_id::text);
    end if;
  end loop;
  loop
    made_count:=0;
    for node_item in select value from jsonb_array_elements(p_backup->'nodes') loop
      legacy_id:=node_item->>'legacy_id'; parent_legacy_id:=node_item->>'legacy_parent_id';
      if parent_legacy_id is not null and not (node_map ? legacy_id) and node_map ? parent_legacy_id then
        insert into public.mm_nodes(session_id,group_no,branch_id,parent_id,text,layout_x,layout_y,bend_x,bend_y) values(s.id,(node_item->>'group_no')::int,(branch_map->>(node_item->>'branch_legacy_id'))::uuid,(node_map->>parent_legacy_id)::uuid,btrim(node_item->>'text'),(node_item->>'layout_x')::double precision,(node_item->>'layout_y')::double precision,(node_item->>'bend_x')::double precision,(node_item->>'bend_y')::double precision) returning id into new_id;
        node_map:=node_map||jsonb_build_object(legacy_id,new_id::text); made_count:=made_count+1;
      end if;
    end loop;
    exit when made_count=0;
  end loop;
  select count(*) into restored_count from jsonb_object_keys(node_map);
  if restored_count<>item_count then raise exception 'Zyklische oder unvollständige Knotenstruktur im Backup'; end if;
  return jsonb_build_object('session',jsonb_build_object('id',s.id,'code',s.code,'title',s.title,'template_key',s.template_key,'is_open',s.is_open,'created_at',s.created_at,'participants_can_export',s.participants_can_export,'root_position',s.root_position,'root_orientation',s.root_orientation),'moderator_token',tok);
end $$;

grant execute on function public.create_session(text,text,text[]) to anon, authenticated;
grant execute on function public.get_session_public(text) to anon, authenticated;
grant execute on function public.get_group_nodes(text,int) to anon, authenticated;
grant execute on function public.add_node(text,int,uuid,uuid,text) to anon, authenticated;
grant execute on function public.update_node(text,int,uuid,text) to anon, authenticated;
grant execute on function public.delete_node(text,int,uuid) to anon, authenticated;
grant execute on function public.moderator_snapshot(text,text) to anon, authenticated;
grant execute on function public.set_session_open(text,text,boolean) to anon, authenticated;
grant execute on function public.mark_collected(text,text) to anon, authenticated;
grant execute on function public.reset_session_to_template(text,text) to anon, authenticated;
grant execute on function public.update_session_settings(text,text,text,text,boolean) to anon, authenticated;
grant execute on function public.update_branch_color(text,text,uuid,text) to anon, authenticated;
grant execute on function public.moderator_add_branch(text,text,text) to anon, authenticated;
grant execute on function public.moderator_add_node(text,text,uuid,uuid,text) to anon, authenticated;
grant execute on function public.moderator_update_node(text,text,uuid,text) to anon, authenticated;
grant execute on function public.moderator_move_node(text,text,uuid,uuid) to anon, authenticated;
grant execute on function public.update_layout_item(text,text,text,uuid,double precision,double precision) to anon, authenticated;
grant execute on function public.update_layout_bend(text,text,text,uuid,double precision,double precision) to anon, authenticated;
grant execute on function public.moderator_reparent_node(text,text,uuid,uuid) to anon, authenticated;
grant execute on function public.moderator_delete_node(text,text,uuid) to anon, authenticated;
grant execute on function public.delete_session(text,text) to anon, authenticated;
grant execute on function public.restore_session_from_backup(jsonb) to anon, authenticated;

-- Hilfsfunktionen nicht direkt aus dem Browser aufrufen.
revoke execute on function public.mm_make_code() from public, anon, authenticated;
revoke execute on function public.mm_token_ok(uuid,text) from public, anon, authenticated;
revoke execute on function public.cleanup_old_mindmap_sessions() from public, anon, authenticated;

-- PostgREST soll die gerade angelegten RPCs ohne Wartezeit erkennen.
notify pgrst, 'reload schema';
