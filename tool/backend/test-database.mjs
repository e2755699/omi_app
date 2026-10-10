// 真正執行 Postgres SQL 與 RLS；Auth/Storage 基礎表為測試替身。
// 這不是 Supabase 雲端 Auth、Storage HTTP 或 Realtime 的整合驗證。
// node tool/backend/test-database.mjs <已安裝的 @electric-sql/pglite/dist/index.js>
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(process.argv[2] ? pathToFileURL(process.argv[2]).href : '@electric-sql/pglite');
const db = new PGlite();
let passed = 0;
const alice = '00000000-0000-0000-0000-000000000001';
const bob = '00000000-0000-0000-0000-000000000002';
const eve = '00000000-0000-0000-0000-000000000003';
async function user(id) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id ?? '']);
  await db.exec(`set role ${id ? 'authenticated' : 'anon'}`);
}
async function scalar(sql, params = []) { return Object.values((await db.query(sql, params)).rows[0])[0]; }
async function equal(sql, expected, params = []) {
  assert.equal(await scalar(sql, params), expected, sql); passed++;
}
async function denied(sql, params = [], code = '42501') {
  await assert.rejects(db.query(sql, params), error => error.code === code); passed++;
}
try {
  await db.exec(`
    set timezone = 'UTC';
    create role anon;
    create role authenticated;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth, public, storage to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    create table storage.buckets(id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),
      bucket_id text references storage.buckets(id), name text not null, unique(bucket_id, name));
    alter table storage.objects enable row level security;
    grant select, insert, update, delete on storage.objects to authenticated;
    insert into auth.users(id) values ('${alice}'), ('${bob}'), ('${eve}');
  `);
  const migrations = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(migrations)).filter(name => name.endsWith('.sql')).sort()) {
    await db.exec(await readFile(new URL(file, migrations), 'utf8'));
  }
  passed++;
  await user(null);
  await denied('select * from public.profiles');
  await denied("select public.create_challenge_group('test', current_date-2, current_date+20, current_date-2, array['produce','water'])");
  await user(alice);
  await db.query('insert into public.profiles(user_id, display_name) values ($1, $2)', [alice, 'Alice']);
  const group = await scalar("select public.create_challenge_group('Omi', current_date-2, current_date+20, current_date-2, array['produce','water'], 'UTC')");
  const invite = await scalar('select public.rotate_group_invite($1)', [group]);
  await denied('select * from private.group_invites');
  await denied("insert into public.memberships(group_id,user_id,starts_on,nourish_choice) values ($1,$2,current_date,array['produce','water'])", [group, eve]);
  await user(bob);
  await equal('select count(*)::int from public.challenge_groups', 0);
  await equal('select public.join_challenge_group($1,current_date-2,array[\'produce\',\'water\'])', group, [invite]);
  await denied('select public.rotate_group_invite($1)', [group]);
  await user(alice);
  await db.query("insert into public.checkins(group_id,user_id,period_date,item_id,amount) values ($1,$2,current_date,'reading',1)", [group, alice]);
  await db.query("insert into public.personal_settings(group_id,user_id,weight_kg) values ($1,$2,60)", [group, alice]);
  await db.query("insert into public.reflections(group_id,user_id,period_date,item_id,answers) values ($1,$2,current_date,'noticed',array['private journal'])", [group, alice]);
  await equal("select amount from public.checkins where item_id='noticed'", 1);
  await denied("insert into public.checkins(group_id,user_id,period_date,item_id,amount) values ($1,$2,date_trunc('week',current_date)::date,'review',3)", [group, alice]);
  await denied("insert into public.checkins(group_id,user_id,period_date,item_id,amount) values ($1,$2,current_date+1,'reading',1)", [group, alice], '23514');
  await denied("insert into public.checkins(group_id,user_id,period_date,item_id,amount) values ($1,$2,current_date-3,'reading',1)", [group, alice], '23514');
  await denied("insert into public.checkins(group_id,user_id,period_date,item_id,amount) values ($1,$2,current_date,'aerobic',1441)", [group, alice], '23514');
  await db.query("update public.checkins set amount=0,version=1 where item_id='reading'");
  await equal("select version::int from public.checkins where item_id='reading'", 2);
  await denied("update public.checkins set amount=1,version=1 where item_id='reading'", [], '40001');
  await db.query("update public.reflections set answers=array[''],version=1 where item_id='noticed'");
  await equal("select amount from public.checkins where item_id='noticed'", 0);
  await denied("select public.update_enrollment($1,current_date,array['produce','water'])", [group], '23514');
  await denied("select public.update_enrollment($1,current_date-2,array['water','water'])", [group], '23514');
  await db.query("select public.update_enrollment($1,current_date-2,array['produce','protein','water'])", [group]);
  await equal('select version::int from public.memberships where user_id=$1', 2, [alice]);
  await db.query("update public.memberships set nourish_choice=array['produce','water'],version=2 where user_id=$1 and version=2", [alice]);
  await equal('select version::int from public.memberships where user_id=$1', 3, [alice]);
  await denied('update public.memberships set starts_on=current_date,version=3 where user_id=$1', [alice], '23514');
  await denied('update public.memberships set active=false where user_id=$1', [alice]);
  assert.equal((await db.query("update public.memberships set nourish_choice=array['water','protein'],version=2 where user_id=$1 and version=2 returning *", [alice])).rows.length, 0); passed++;
  await user(bob);
  assert.equal((await db.query("update public.memberships set nourish_choice=array['water','protein'],version=3 where user_id=$1 returning *", [alice])).rows.length, 0); passed++;
  await equal('select count(*)::int from public.profiles', 1);
  await equal('select count(*)::int from public.checkins', 2);
  await equal('select count(*)::int from public.personal_settings', 0);
  await equal('select count(*)::int from public.reflections', 0);
  await denied("insert into public.checkins(group_id,user_id,period_date,item_id,amount) values ($1,$2,current_date,'sleep',1)", [group, alice]);
  assert.equal((await db.query("update public.checkins set amount=1,version=2 where user_id=$1 returning *", [alice])).rows.length, 0); passed++;
  await db.query("select public.send_cheer($1,$2,'cheer')", [group, alice]);
  await db.query("select public.send_cheer($1,$2,'cheer')", [group, alice]);
  await equal('select count(*)::int from public.cheers', 1);
  await denied("select public.send_cheer($1,$2,'cheer')", [group, bob]);
  await user(eve);
  await equal('select count(*)::int from public.profiles', 0);
  await equal('select count(*)::int from public.checkins', 0);
  await equal('select count(*)::int from public.reflections', 0);
  await equal('select count(*)::int from public.weekly_photos', 0);
  await denied("select public.join_challenge_group('invalid',current_date,array['produce','water'])");
  await denied("select public.send_cheer($1,$2,'cheer')", [group, alice]);
  await user(alice);
  const monday = await scalar("select to_char(date_trunc('week',current_date),'YYYY-MM-DD')");
  const path = `${group}/${alice}/${monday}/photo.jpg`;
  await denied('insert into public.weekly_photos(group_id,user_id,period_date,object_path) values ($1,$2,$3,$4)', [group, alice, monday, path], '23514');
  await db.query("insert into storage.objects(bucket_id,name) values ('weekly-photos',$1)", [path]);
  await user(bob);
  await equal('select count(*)::int from storage.objects', 0);
  await user(alice);
  await db.query('insert into public.weekly_photos(group_id,user_id,period_date,object_path) values ($1,$2,$3,$4)', [group, alice, monday, path]);
  await equal("select amount from public.checkins where item_id='photo'", 1);
  await user(bob);
  await equal('select count(*)::int from storage.objects', 1);
  await denied("insert into storage.objects(bucket_id,name) values ('weekly-photos',$1)", [`${group}/${alice}/${monday}/forged.jpg`]);
  await db.query('select public.leave_challenge_group($1)', [group]);
  await equal('select count(*)::int from public.checkins', 0);
  await equal('select count(*)::int from storage.objects', 0);
  await equal('select count(*)::int from public.cheers', 0);
  await denied("select public.send_cheer($1,$2,'cheer')", [group, alice]);
  await user(eve);
  await equal('select count(*)::int from storage.objects', 0);
  await user(alice);
  await db.query('update public.weekly_photos set object_path=null,version=1');
  await equal("select amount from public.checkins where item_id='photo'", 0);
  await db.query('delete from storage.objects where name=$1', [path]);
  await equal('select count(*)::int from storage.objects', 0);
  await db.query('select public.rotate_group_invite($1)', [group]);
  await user(bob);
  await denied("select public.join_challenge_group($1,current_date,array['produce','water'])", [invite]);
  console.log(`PASS: ${passed} database assertions (PGlite; Auth/Storage base schemas mocked).`);
} catch (error) {
  console.error({ passed, message: error.message, code: error.code, query: error.query });
  process.exitCode = 1;
} finally { await db.close(); }
