-- LOXSMAX V1: run this once in Supabase SQL Editor.
-- Creates public media storage and a sounds catalog linked to uploaded audio.

create table if not exists public.sounds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  audio_url text not null,
  created_at timestamptz not null default now()
);

alter table public.videos
  add column if not exists sound_id uuid references public.sounds(id) on delete set null;

alter table public.sounds enable row level security;

drop policy if exists "Sounds are public" on public.sounds;
create policy "Sounds are public"
on public.sounds for select
using (true);

drop policy if exists "Users upload own sounds" on public.sounds;
create policy "Users upload own sounds"
on public.sounds for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users delete own sounds" on public.sounds;
create policy "Users delete own sounds"
on public.sounds for delete to authenticated
using (auth.uid() = user_id);

grant select on public.sounds to anon, authenticated;
grant insert, delete on public.sounds to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  true,
  104857600,
  array['video/mp4','video/webm','video/quicktime','audio/mpeg','audio/mp4','audio/aac','audio/wav','audio/ogg']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 104857600,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view LOXSMAX media" on storage.objects;
create policy "Public can view LOXSMAX media"
on storage.objects for select
using (bucket_id = 'media');

drop policy if exists "Authenticated users upload own LOXSMAX media" on storage.objects;
create policy "Authenticated users upload own LOXSMAX media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users delete own LOXSMAX media" on storage.objects;
create policy "Users delete own LOXSMAX media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
