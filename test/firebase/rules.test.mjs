import {before, after, test} from 'node:test';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs, serverTimestamp} from 'firebase/firestore';

let env;
before(async()=>{
  env=await initializeTestEnvironment({projectId:'demo-subako',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context=>{
    const db=context.firestore();
    const fixtures={
      'users/viewer':{name:'Viewer',siteIds:['a'],active:true},
      'users/outsider':{name:'Other',siteIds:['b'],active:true},
      'users/admin':{name:'Admin',siteIds:['a'],active:true},
      'users/revoked':{name:'Revoked',siteIds:['a'],active:true},
      'users/disabled':{name:'Disabled',siteIds:['a'],active:false},
      'sites/a':{name:'Subak A'},'sites/b':{name:'Subak B'},
      'sites/a/members/viewer':{role:'farmer_viewer',permissions:['dashboard.view'],active:true},
      'sites/a/members/admin':{role:'mikiko_admin',permissions:['audit.view'],active:true},
      'sites/a/members/revoked':{role:'operator',permissions:['audit.view'],active:false},
      'sites/a/members/disabled':{role:'operator',permissions:['audit.view'],active:true},
      'devices/gate-a':{siteId:'a'},'devices/gate-b':{siteId:'b'},
      'telemetryLatest/gate-a':{siteId:'a',upstreamCm:24},
      'telemetryLatest/gate-b':{siteId:'b',upstreamCm:99},
      'waterRules/rule-a':{siteId:'a',status:'PUBLISHED'},
      'waterLedger/entry-a':{siteId:'a',hash:'immutable'},
      'alerts/alert-a':{siteId:'a',acknowledged:false},
      'auditEvents/event-a':{siteId:'a'},
      'chatSessions/own':{ownerUid:'viewer',siteId:'a',createdAt:new Date(),updatedAt:new Date()},
      'chatSessions/other':{ownerUid:'outsider',siteId:'b'},
      'fcmTokens/own':{ownerUid:'viewer',token:'example-only',platform:'android',updatedAt:new Date()},
    };
    for(const [path,data] of Object.entries(fixtures))await setDoc(doc(db,path),data);
  });
});
after(async()=>{await env?.cleanup()});
const dbFor=uid=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();

test('unauthenticated and unrelated users cannot read site data',async()=>{
  await assertFails(getDoc(doc(dbFor(null),'sites/a')));
  await assertFails(getDoc(doc(dbFor('outsider'),'devices/gate-a')));
});
test('own profile only; clients cannot grant themselves roles',async()=>{
  const db=dbFor('viewer');await assertSucceeds(getDoc(doc(db,'users/viewer')));
  await assertFails(getDoc(doc(db,'users/outsider')));
  await assertFails(updateDoc(doc(db,'users/viewer'),{role:'platform_admin'}));
  await assertFails(setDoc(doc(db,'sites/a/members/viewer'),{role:'pekaseh',active:true,permissions:['rule.approve']}));
});
test('authorized site and scoped device queries work; cross-site denied',async()=>{
  const db=dbFor('viewer');await assertSucceeds(getDoc(doc(db,'sites/a')));
  await assertSucceeds(getDocs(query(collection(db,'devices'),where('siteId','==','a'))));
  await assertFails(getDocs(collection(db,'devices')));
  await assertFails(getDoc(doc(db,'sites/b')));
  await assertFails(getDoc(doc(db,'telemetryLatest/gate-b')));
});
test('revoked membership cannot read previously authorized site',async()=>{
  await assertFails(getDoc(doc(dbFor('revoked'),'devices/gate-a')));
  await assertFails(getDoc(doc(dbFor('disabled'),'devices/gate-a')));
});
test('telemetry, rules, ledger, command and audit writes are server-only',async()=>{
  for(const uid of ['viewer','admin'])for(const path of ['telemetryLatest/gate-a','waterRules/rule-a','waterLedger/entry-a','commands/new','auditEvents/new'])
    await assertFails(setDoc(doc(dbFor(uid),path),{siteId:'a'}));
  await assertFails(updateDoc(doc(dbFor('viewer'),'alerts/alert-a'),{acknowledged:true}));
});
test('audit read requires explicit permission',async()=>{
  await assertFails(getDoc(doc(dbFor('viewer'),'auditEvents/event-a')));
  await assertSucceeds(getDoc(doc(dbFor('admin'),'auditEvents/event-a')));
});
test('unknown site subcollections remain denied',async()=>{
  await assertFails(getDoc(doc(dbFor('viewer'),'sites/a/privateSecrets/key')));
});
test('chat read and creation require owner and current site membership',async()=>{
  const db=dbFor('viewer');await assertSucceeds(getDoc(doc(db,'chatSessions/own')));
  await assertFails(getDoc(doc(db,'chatSessions/other')));
  await assertSucceeds(setDoc(doc(db,'chatSessions/new'),{ownerUid:'viewer',siteId:'a',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db,'chatSessions/cross-site'),{ownerUid:'viewer',siteId:'b',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'chatSessions/own'),{ownerUid:'outsider'}));
});
test('chat messages cannot forge assistant output or exceed bounded input',async()=>{
  const db=dbFor('viewer');const base={ownerUid:'viewer',role:'user',text:'Jelaskan kondisi air',createdAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db,'chatSessions/own/messages/new'),base));
  await assertFails(setDoc(doc(db,'chatSessions/own/messages/forged'),{...base,role:'assistant'}));
  await assertFails(setDoc(doc(db,'chatSessions/own/messages/huge'),{...base,text:'a'.repeat(2001)}));
  await assertFails(setDoc(doc(dbFor('outsider'),'chatSessions/own/messages/other'),{...base,ownerUid:'outsider'}));
});
test('FCM token CRUD works for owner; ownership cannot be stolen',async()=>{
  const db=dbFor('viewer');await assertSucceeds(getDoc(doc(db,'fcmTokens/own')));
  await assertFails(getDoc(doc(dbFor('outsider'),'fcmTokens/own')));
  await assertSucceeds(setDoc(doc(db,'fcmTokens/new'),{ownerUid:'viewer',token:'new-token',platform:'android',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'fcmTokens/new'),{ownerUid:'outsider'}));
  await assertSucceeds(deleteDoc(doc(db,'fcmTokens/new')));
});
