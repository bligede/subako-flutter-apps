const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const path=require('node:path');
const sdk=createRequire(path.resolve('functions/package.json'));
const {initializeApp,deleteApp}=sdk('firebase-admin/app');
const {getFirestore,Timestamp}=sdk('firebase-admin/firestore');
let app,db;const tokens={};
before(async()=>{
  assert(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST,'Emulators required');
  app=initializeApp({projectId:'demo-subako'});db=getFirestore(app);
  for(const role of ['viewer','operator','outsider']){
    const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`,{
      method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${role}@demo.subako.test`,password:'EmulatorOnly-2026',returnSecureToken:true})});
    const value=await response.json();assert(response.ok);tokens[role]={idToken:value.idToken,uid:value.localId};
    await db.doc(`users/${value.localId}`).set({active:true});
    if(role!=='outsider')await db.doc(`sites/a/members/${value.localId}`).set({role,active:true,
      permissions:['dashboard.view',...(role==='operator'?['alert.acknowledge']:[])]});
  }
  await db.doc('sites/a').set({name:'Test Subak A'});
  await db.doc('devices/a-node').set({name:'Node A',siteId:'a',kind:'MEASUREMENT',mode:'IDLE'});
  await db.doc('telemetryLatest/a-node').set({siteId:'a',source:'SIMULATION',recordedAt:Timestamp.now(),quality:'OK',upstreamCm:31.5});
  await db.doc('devices/b-node').set({name:'Secret B',siteId:'b'});
  await db.doc('alerts/alert-a').set({siteId:'a',acknowledged:false,title:'Test',severity:'INFO'});
});
after(async()=>{if(app)await deleteApp(app)});
async function call(name,role,data){
  const response=await fetch(`http://127.0.0.1:5001/demo-subako/asia-southeast2/${name}`,{
    method:'POST',headers:{'Content-Type':'application/json',...(role?{Authorization:'Bearer '+tokens[role].idToken}:{})},body:JSON.stringify({data})});
  return {status:response.status,...await response.json()};
}
test('callable rejects missing auth and cross-site context',async()=>{
  assert.equal((await call('getAiContext',null,{siteId:'a'})).error.status,'UNAUTHENTICATED');
  assert.equal((await call('getAiContext','outsider',{siteId:'a'})).error.status,'PERMISSION_DENIED');
});
test('authorized AI context contains only selected site and source timestamps',async()=>{
  const res=await call('getAiContext','viewer',{siteId:'a'});assert.equal(res.status,200);
  assert.equal(res.result.siteName,'Test Subak A');assert.equal(res.result.readings.length,1);
  assert.equal(res.result.readings[0].dataState,'SIMULATION');assert(!JSON.stringify(res).includes('Secret B'));
});
test('acknowledgement is authorized, audited and idempotent',async()=>{
  assert.equal((await call('acknowledgeAlert','viewer',{alertId:'alert-a'})).error.status,'PERMISSION_DENIED');
  for(let i=0;i<2;i++)assert.equal((await call('acknowledgeAlert','operator',{alertId:'alert-a'})).status,200);
  const alert=(await db.doc('alerts/alert-a').get()).data();assert.equal(alert.acknowledged,true);
  assert.equal(alert.acknowledgedBy,tokens.operator.uid);
  assert.equal((await db.collection('auditEvents').where('target','==','alert-a').get()).size,1);
});
test('physical command path is closed before commissioning',async()=>{
  const response=await call('createGateCommand','operator',{gateId:'a-node',siteId:'a',targetPositionPercent:100});
  assert.equal(response.error.status,'FAILED_PRECONDITION');assert.equal((await db.collection('commands').get()).size,0);
});
test('revocation takes effect on next callable even with previous ID token',async()=>{
  await db.doc(`sites/a/members/${tokens.viewer.uid}`).update({active:false});
  assert.equal((await call('getAiContext','viewer',{siteId:'a'})).error.status,'PERMISSION_DENIED');
});
