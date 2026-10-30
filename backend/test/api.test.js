import {test,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {newDb} from 'pg-mem';
import request from 'supertest';
import {createApp} from '../src/app.js';
import {hash} from '../src/security.js';
let app,pool,mails;
beforeEach(async()=>{
 const db=newDb(); const pg=db.adapters.createPg();pool=new pg.Pool();
 await pool.query(await readFile(new URL('../src/schema.sql',import.meta.url),'utf8'));
 mails=[];app=createApp({pool,env:{JWT_SECRET:'test-secret-with-more-than-32-characters'},sendMail:async(email,code)=>mails.push({email,code})});
});
async function register(username='parent1'){
 const r=await request(app).post('/auth/register').send({username,email:username+'@example.com',name:'Test Parent',password:'StrongPass123!'}).expect(201);
 const code=mails.at(-1).code;
 const s=await request(app).post('/auth/otp').send({challengeId:r.body.challengeId,code}).expect(200);
 return {...s.body,challenge:r.body.challengeId,code};
}
const agent=token=>({Authorization:'Bearer '+token});
test('Swagger UI and OpenAPI specification are publicly available',async()=>{
 const spec=await request(app).get('/openapi.json').expect(200);
 assert.equal(spec.body.openapi,'3.0.3');
 assert.equal(spec.body.info.title,'An Tâm Số API');
 assert.ok(spec.body.tags.some(tag=>tag.name==='Hệ thống'));
 assert.ok(spec.body.paths['/children/{id}'].delete);
 assert.deepEqual(spec.body.paths['/me'].get.security,[{bearerAuth:[]}]);
 const docs=await request(app).get('/docs/').expect(200);
 assert.match(docs.headers['content-type'],/text\/html/);
 assert.match(docs.headers['content-security-policy'],/script-src 'self' 'unsafe-inline'/);
 assert.match(docs.text,/Swagger UI/);
});
test('registration verifies OTP, stores only digest and rejects replay',async()=>{
 const u=await register();assert.equal(u.user.role,'parent');assert.ok(u.token);assert.equal(u.user.password,undefined);
 assert.equal(u.user.hasPassword,true);
 await request(app).post('/auth/otp').send({challengeId:u.challenge,code:u.code}).expect(401);
 await request(app).get('/me').set(agent(u.token)).expect(200);
 await request(app).get('/me').expect(401);
});
test('users can update their display name without changing login identifiers',async()=>{
 const user=await register();
 const updated=await request(app).patch('/me').set(agent(user.token)).send({name:'Updated Parent'}).expect(200);
 assert.equal(updated.body.name,'Updated Parent');
 assert.equal(updated.body.email,user.user.email);
 assert.equal(updated.body.username,user.user.username);
 await request(app).patch('/me').set(agent(user.token)).send({name:' '}).expect(400);
 assert.equal((await request(app).get('/me').set(agent(user.token)).expect(200)).body.name,'Updated Parent');
});
test('Google account can set a password; password accounts must verify the current password',async()=>{
 const {randomUUID}=await import('node:crypto'),verifier='v'.repeat(40),code='g'.repeat(40);
 const google=(await pool.query(
  "INSERT INTO users(id,email,username,name,verified) VALUES($1,$2,$3,$4,true) RETURNING *",
  [randomUUID(),'google@example.com','google_user','Google User'],
 )).rows[0];
 await pool.query("INSERT INTO challenges(id,user_id,kind,digest,expires_at,payload) VALUES($1,$2,'oauth-exchange',$3,now()+interval '1 minute',$4)",[randomUUID(),google.id,hash(code),JSON.stringify({verifierHash:hash(verifier)})]);
 const login=await request(app).post('/auth/google/exchange').send({code,verifier}).expect(200);
 assert.equal(login.body.user.hasPassword,false);
 const token=login.body.token;
 await request(app).patch('/me/password').set(agent(token)).send({newPassword:'GooglePass123!'}).expect(200);
 const me=await request(app).get('/me').set(agent(token)).expect(200);
 assert.equal(me.body.hasPassword,true);
 await request(app).patch('/me/password').set(agent(token)).send({newPassword:'AnotherPass123!'}).expect(401);
 await request(app).patch('/me/password').set(agent(token)).send({currentPassword:'GooglePass123!',newPassword:'AnotherPass123!'}).expect(200);
 const passwordLogin=await request(app).post('/auth/login').send({username:'google_user',password:'AnotherPass123!'}).expect(200);
 assert.equal(passwordLogin.body.token,undefined);
 assert.equal(passwordLogin.body.kind,'login');
 await request(app).post('/auth/otp').send({challengeId:passwordLogin.body.challengeId,code:mails.at(-1).code}).expect(200);
});
test('failed registration email removes the incomplete account',async()=>{
 app=createApp({
  pool,
  env:{JWT_SECRET:'test-secret-with-more-than-32-characters'},
  sendMail:async()=>{throw Object.assign(new Error('mail unavailable'),{status:503});},
 });
 await request(app).post('/auth/register').send({
  username:'retry_user',
  email:'retry@example.com',
  name:'Test Parent',
  password:'StrongPass123!',
 }).expect(503);
 assert.equal(Number((await pool.query('SELECT count(*) FROM users')).rows[0].count),0);
 assert.equal(Number((await pool.query('SELECT count(*) FROM challenges')).rows[0].count),0);
});
test('password login needs email OTP; wrong attempts lock challenge',async()=>{
 await register();await request(app).post('/auth/login').send({username:'parent1',password:'wrong'}).expect(401);
 const r=await request(app).post('/auth/login').send({username:'parent1',password:'StrongPass123!'}).expect(200);
 assert.equal(r.body.token,undefined);assert.equal(r.body.code,undefined);
 const wrong=mails.at(-1).code==='000000'?'111111':'000000';
 for(let i=0;i<5;i++)await request(app).post('/auth/otp').send({challengeId:r.body.challengeId,code:wrong}).expect(401);
 await request(app).post('/auth/otp').send({challengeId:r.body.challengeId,code:mails.at(-1).code}).expect(401);
 const c=(await pool.query('SELECT * FROM challenges WHERE id=$1',[r.body.challengeId])).rows[0];assert.equal(c.digest,hash(mails.at(-1).code));assert.equal(c.attempts,5);
});
test('email-only login sends OTP without requiring a password',async()=>{
 const user=await register('otp_only');
 const challenge=await request(app).post('/auth/login/otp').send({username:'OTP_ONLY@EXAMPLE.COM'}).expect(200);
 assert.equal(challenge.body.kind,'login');
 assert.equal(challenge.body.token,undefined);
 assert.equal(mails.at(-1).email,'otp_only@example.com');
 const session=await request(app).post('/auth/otp').send({
  challengeId:challenge.body.challengeId,
  code:mails.at(-1).code,
 }).expect(200);
 assert.equal(session.body.user.id,user.user.id);
 await request(app).post('/auth/login/otp').send({username:'missing@example.com'}).expect(401);
});
test('CRUD is isolated between families and validates limits',async()=>{
 const a=await register('family_a'),b=await register('family_b');
 const c=await request(app).post('/children').set(agent(a.token)).send({name:'An',age:9,daily_limit:90}).expect(201);
 await request(app).put('/children/'+c.body.id).set(agent(b.token)).send({name:'Hack',age:9,daily_limit:90}).expect(404);
 await request(app).post('/children').set(agent(a.token)).send({name:'An',age:99,daily_limit:0}).expect(400);
 const list=await request(app).get('/children').set(agent(b.token)).expect(200);assert.equal(list.body.length,0);
 const d=await request(app).post(`/children/${c.body.id}/devices`).set(agent(a.token)).send({name:'Phone'}).expect(201);
 await request(app).put('/devices/'+d.body.id).set(agent(a.token)).send({name:'New Phone'}).expect(200);
 await request(app).delete('/devices/'+d.body.id).set(agent(b.token)).expect(404);
 await request(app).delete('/devices/'+d.body.id).set(agent(a.token)).expect(204);
 await request(app).delete('/children/'+c.body.id).set(agent(a.token)).expect(204);
});
test('NFC binds a tag; agreements require parent approval',async()=>{
 const a=await register();const c=(await request(app).post('/children').set(agent(a.token)).send({name:'An',age:9,daily_limit:90})).body;
 const path='/children/'+c.id;await request(app).put(path+'/nfc').set(agent(a.token)).send({tagHash:hash('tag')}).expect(200);
 await request(app).post(path+'/checkins').set(agent(a.token)).send({tagHash:hash('wrong')}).expect(403);
 await request(app).post(path+'/checkins').set(agent(a.token)).send({tagHash:hash('tag')}).expect(201);
 const checks=await request(app).get(path+'/checkins').set(agent(a.token)).expect(200);assert.equal(checks.body.length,1);
 const r=await request(app).post(path+'/agreements').set(agent(a.token)).send({title:'Read books',reward:15}).expect(201);
 await request(app).patch('/agreements/'+r.body.id).set(agent(a.token)).send({status:'approved'}).expect(200);
});
test('registration cannot grant admin; staff cannot access family data',async()=>{
 const a=await register();await request(app).get('/admin/users').set(agent(a.token)).expect(403);
 await pool.query("UPDATE users SET role='staff' WHERE id=$1",[a.user.id]);
 await request(app).get('/staff/dashboard').set(agent(a.token)).expect(200);
 await request(app).post('/children').set(agent(a.token)).send({name:'An',age:9,daily_limit:90}).expect(403);
});

test('Google exchange for password account requires OTP and preserves account',async()=>{
 const u=await register();const {randomUUID}=await import('node:crypto');const verifier='v'.repeat(40),code='c'.repeat(40);
 await pool.query("INSERT INTO challenges(id,user_id,kind,digest,expires_at,payload) VALUES($1,$2,'oauth-exchange',$3,now()+interval '1 minute',$4)",[randomUUID(),u.user.id,hash(code),JSON.stringify({verifierHash:hash(verifier)})]);
 await request(app).post('/auth/google/exchange').send({code,verifier:'wrong'.repeat(8)}).expect(401);
 const r=await request(app).post('/auth/google/exchange').send({code,verifier}).expect(200);
 assert.equal(r.body.requiresOtp,true);assert.equal(r.body.token,undefined);
 const verified=await request(app).post('/auth/otp').send({challengeId:r.body.challengeId,code:mails.at(-1).code}).expect(200);
 assert.equal(verified.body.user.id,u.user.id);
 await request(app).post('/auth/google/exchange').send({code,verifier}).expect(401);
});

test('Google OAuth start and callback failures return to the app',async()=>{
 const start=await request(app).get('/auth/google/start').query({verifierHash:'a'.repeat(64)}).expect(302);
 assert.match(start.headers.location,/^childguard:\/\/auth\?error=/);
 assert.equal(new URL(start.headers.location).searchParams.get('error'),'Google OAuth chưa được cấu hình');

 const callback=await request(app).get('/auth/google/callback').expect(302);
 assert.match(callback.headers.location,/^childguard:\/\/auth\?error=/);
 assert.equal(new URL(callback.headers.location).searchParams.get('error'),'Không thể hoàn tất đăng nhập Google. Vui lòng thử lại.');
});

test('Google OAuth asks Google to show the account chooser',async()=>{
 app=createApp({
  pool,
  env:{
   JWT_SECRET:'test-secret-with-more-than-32-characters',
   GOOGLE_CLIENT_ID:'test-client.apps.googleusercontent.com',
   GOOGLE_CLIENT_SECRET:'test-client-secret',
   RENDER_EXTERNAL_URL:'https://api.example.com',
  },
  sendMail:async(email,code)=>mails.push({email,code}),
 });
 const start=await request(app).get('/auth/google/start').query({verifierHash:'a'.repeat(64)}).expect(302);
 const authorizationUrl=new URL(start.headers.location);
 assert.equal(authorizationUrl.searchParams.get('prompt'),'select_account');
 assert.equal(authorizationUrl.searchParams.get('redirect_uri'),'https://api.example.com/auth/google/callback');
});

test('location sharing is opt-in, family-scoped, validated, and removable by linked child',async()=>{
 const parent=await register('locparent'),child=await register('locchild'),other=await register('locother');
 await pool.query("UPDATE users SET role='child' WHERE id=$1",[child.user.id]);
 const c=(await request(app).post('/children').set(agent(parent.token)).send({name:'An',age:9,daily_limit:90}).expect(201)).body;
 await pool.query('INSERT INTO child_links(user_id,child_id) VALUES($1,$2)',[child.user.id,c.id]);
 const path=`/children/${c.id}/location`;
 const point={latitude:10.8,longitude:106.7,accuracy:15};
 await request(app).put(path).set(agent(parent.token)).send(point).expect(403);
 await request(app).put(path).set(agent(child.token)).send({...point,latitude:999}).expect(400);
 await request(app).put(path).set(agent(child.token)).send(point).expect(200);
 const saved=await request(app).get(path).set(agent(parent.token)).expect(200);
 assert.equal(saved.body.latitude,point.latitude);
 await request(app).get(path).set(agent(other.token)).expect(404);
 await request(app).delete(path).set(agent(other.token)).expect(403);
 await request(app).delete(path).set(agent(child.token)).expect(204);
 const empty=await request(app).get(path).set(agent(parent.token)).expect(200);
 assert.equal(empty.body,null);
});
