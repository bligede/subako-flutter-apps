// Explicit development project only; uses existing Firebase CLI user login.
// Tokens and demo passwords are never printed or committed.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..'), project='subako-dev-mikiko';
const sdkRequire=createRequire(path.join(root,'functions/package.json'));
const {initializeApp}=sdkRequire('firebase-admin/app');
const {getAuth}=sdkRequire('firebase-admin/auth');
const {getFirestore,Timestamp}=sdkRequire('firebase-admin/firestore');
const cliPath=process.env.SUBAKO_FIREBASE_CLI_ROOT || path.dirname(require.resolve('firebase-tools/package.json'));
const {getAccessToken}=require(path.join(cliPath,'lib/auth.js'));
const local=path.join(root,'.local');fs.mkdirSync(local,{recursive:true});
async function token(){
 const config=JSON.parse(fs.readFileSync(path.join(process.env.USERPROFILE || process.env.HOME,'.config/configstore/firebase-tools.json'),'utf8'));
 const result=await getAccessToken(config.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
 return result.access_token;
}
async function api(url,method='GET',body){
 const response=await fetch(url,{method,headers:{Authorization:'Bearer '+await token(),'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(60000)});
 const value=await response.json();if(!response.ok)throw new Error(`Cloud setup failed: ${response.status}: ${value.error?.message ?? 'See console'}`);return value;
}
async function setup(){
 const result=await api(`https://serviceusage.googleapis.com/v1/projects/272154271292/services:batchEnable`,'POST',{
   serviceIds:['firestore.googleapis.com','identitytoolkit.googleapis.com','firebaseappcheck.googleapis.com','firebasevertexai.googleapis.com','generativelanguage.googleapis.com']});
 if(result.name)for(let count=0;count<30;count++){
   const operation=await api('https://serviceusage.googleapis.com/v1/'+result.name);
   if(operation.done){if(operation.error)throw new Error('Service activation failed.');break;}
   await new Promise(resolve=>setTimeout(resolve,2000));
 }
 try { await api(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`); }
 catch(error) {
   if(!error.message.includes('CONFIGURATION_NOT_FOUND'))throw error;
   await api(`https://identitytoolkit.googleapis.com/v2/projects/${project}/identityPlatform:initializeAuth`,'POST',{});
 }
 await api(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`,'PATCH',{
   signIn:{email:{enabled:true,passwordRequired:true}}});
 console.log(JSON.stringify({project,apis:'enabled',emailPasswordAuth:'enabled'}));
}
async function seed(){
 const app=initializeApp({projectId:project,credential:{getAccessToken:async()=>({access_token:await token(),expires_in:3000})}});
 const auth=getAuth(app);const now=Timestamp.now();
 const encode=value=>value instanceof Timestamp?{timestampValue:value.toDate().toISOString()}
   :typeof value==='boolean'?{booleanValue:value}:typeof value==='number'?{doubleValue:value}
   :typeof value==='string'?{stringValue:value}:Array.isArray(value)?{arrayValue:{values:value.map(encode)}}
   :{mapValue:{fields:Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]))}};
 const db={doc:key=>{
   const url=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${key}`;
   return {get:async()=>{try{await api(url);return {exists:true};}catch(e){if(e.message.includes('404:'))return {exists:false};throw e;}},
     create:data=>api(url+'?currentDocument.exists=false','PATCH',{fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,encode(v)]))})};
 }};
 const credentialsFile=path.join(local,'firebase-demo-credentials.json');
 const credentials=fs.existsSync(credentialsFile)?JSON.parse(fs.readFileSync(credentialsFile,'utf8')):{project,accounts:{}};
 const roles={petani:'farmer_viewer',operator:'operator',pekaseh:'pekaseh',admin:'mikiko_admin'};
 const common=['dashboard.view','monitoring.view','ledger.view','rule.view'];
 for(const [name,role] of Object.entries(roles)){
   const email=`${name}@demo.subako.local`;
   let user;
   try{user=await auth.getUserByEmail(email);}catch(error){if(error.code!=='auth/user-not-found')throw error;
     const password=crypto.randomBytes(18).toString('base64url');user=await auth.createUser({email,password,displayName:name});
     credentials.accounts[email]={password,role};fs.writeFileSync(credentialsFile,JSON.stringify(credentials,null,2));
   }
   if(!(await db.doc(`users/${user.uid}`).get()).exists)await db.doc(`users/${user.uid}`).create({name,email,active:true,siteIds:['site-sangeh'],createdAt:now});
   const permissions=[...common,...(name==='operator'||name==='pekaseh'||name==='admin'?['alert.acknowledge']:[]),...(name==='pekaseh'?['rule.manage','rule.approve']:[]),...(name==='admin'?['audit.view','device.manage']:[])];
   const member=db.doc(`sites/site-sangeh/members/${user.uid}`);
   if(!(await member.get()).exists)await member.create({role,permissions,active:true,createdAt:now});
 }
 const fixtures={
   'sites/site-sangeh':{name:'Subak Sangeh — Development',village:'Sangeh',regency:'Badung',tempekCount:3,gateCount:1,dataState:'SIMULATION',source:'SIMULATION',createdAt:now},
   'devices/node-01':{name:'Node Air 01',siteId:'site-sangeh',kind:'MEASUREMENT',mode:'IDLE',source:'SIMULATION',lastSeen:now,batteryPercent:92,firmware:'SIM-0.2.1'},
   'devices/gate-01':{name:'Gate-01',siteId:'site-sangeh',kind:'GATE',mode:'IDLE',source:'SIMULATION',lastSeen:now,batteryPercent:88,positionPercent:35,firmware:'SIM-0.2.1'},
   'telemetryLatest/node-01':{siteId:'site-sangeh',source:'SIMULATION',upstreamCm:74.2,downstreamCm:58.1,flowLiterPerSecond:38.5,quality:'OK',recordedAt:now},
   'alerts/dev-review':{siteId:'site-sangeh',deviceId:'node-01',source:'SIMULATION',severity:'INFO',title:'Data development simulasi',evidence:'Bukan pembacaan perangkat lapangan.',suggestedAction:'Gunakan build demo untuk uji interaksi.',raisedAt:now,acknowledged:false},
 };
 for(const [key,value] of Object.entries(fixtures)){const ref=db.doc(key);if(!(await ref.get()).exists)await ref.create(value);}
 console.log(JSON.stringify({project,seed:'SIMULATION fixture created idempotently',credentialsFile,physicalCommands:'disabled'}));
}
module.exports={api,token,project};
if(require.main===module)(process.argv.includes('--seed')?seed():setup()).catch(error=>{console.error(error.message);process.exitCode=1;});
