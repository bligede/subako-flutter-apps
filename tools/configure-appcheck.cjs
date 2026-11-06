const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {api,project}=require('./provision-development.cjs');
const root=path.resolve(__dirname,'..'),configPath=path.join(root,'.local/firebase-development.json');
async function main(){
 const config=JSON.parse(fs.readFileSync(configPath,'utf8'));
 if(config.SUBAKO_FIREBASE_PROJECT_ID!==project)throw new Error('Only the SUBAKO development project is supported.');
 const app=`projects/272154271292/apps/${config.SUBAKO_FIREBASE_APP_ID}`;
 if(!config.SUBAKO_APPCHECK_DEBUG_TOKEN){
   const token=crypto.randomUUID();
   const result=await api(`https://firebaseappcheck.googleapis.com/v1/${app}/debugTokens`,'POST',{
     displayName:'SUBAKO local Android development — 2026-11-06',token});
   config.SUBAKO_APPCHECK_DEBUG_TOKEN=token;
   fs.writeFileSync(configPath,JSON.stringify(config,null,2));
   fs.writeFileSync(path.join(root,'.local/appcheck-debug-registration.json'),JSON.stringify({project,name:result.name,tokenStoredIn:'.local/firebase-development.json'},null,2));
 }
 const response=await fetch(`https://firebaseappcheck.googleapis.com/v1/${app}:exchangeDebugToken?key=${config.SUBAKO_FIREBASE_API_KEY}`,{
   method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({debugToken:config.SUBAKO_APPCHECK_DEBUG_TOKEN}),signal:AbortSignal.timeout(20000)});
 const result=await response.json();if(!response.ok)throw new Error('App Check exchange failed: '+response.status+' '+result.error?.message);
 console.log('App Check debug exchange verified; secret remains in ignored local configuration.');
 // Registration/exchange does not prove generation or enforcement. Record these
 // separately and never enable Gemini just because a debug token was exchanged.
 if(process.argv.includes('--probe')){
   const probe=require('node:child_process').spawnSync(process.execPath,[path.join(__dirname,'verify-online.cjs')],{
     cwd:root,stdio:'inherit',timeout:150000});
   if(probe.error)throw probe.error;
   process.exitCode=probe.status??1;
 }
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
