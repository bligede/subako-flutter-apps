const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const config=JSON.parse(fs.readFileSync(path.join(root,'.local/firebase-development.json'),'utf8'));
const credentials=JSON.parse(fs.readFileSync(path.join(root,'.local/firebase-demo-credentials.json'),'utf8'));
const report={project:config.SUBAKO_FIREBASE_PROJECT_ID,model:config.SUBAKO_GEMINI_MODEL||'gemini-3.8-flash',executedAt:new Date().toISOString()};
const save=()=>fs.writeFileSync(path.join(root,'.local/online-verification.json'),JSON.stringify(report,null,2));
async function json(url,body,headers={},timeout=20000){
 const response=await fetch(url,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...headers},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(timeout)});
 return {status:response.status,value:await response.json()};
}
async function main(){
 const email='pekaseh@demo.subako.local';
 const signed=await json(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${config.SUBAKO_FIREBASE_API_KEY}`,{
   email,password:credentials.accounts[email].password,returnSecureToken:true});
 report.authentication=signed.status;if(signed.status!==200)throw new Error('Firebase sign-in failed');save();
 const base=`https://firestore.googleapis.com/v1/projects/${report.project}/databases/(default)/documents`;
 report.authorizedSite=(await json(base+'/sites/site-sangeh',null,{Authorization:'Bearer '+signed.value.idToken})).status;
 report.unauthorizedSite=(await json(base+'/sites/unauthorized-site',null,{Authorization:'Bearer '+signed.value.idToken})).status;save();
 const app=`projects/272154271292/apps/${config.SUBAKO_FIREBASE_APP_ID}`;
 const token=await json(`https://firebaseappcheck.googleapis.com/v1/${app}:exchangeDebugToken?key=${config.SUBAKO_FIREBASE_API_KEY}`,{
   debugToken:config.SUBAKO_APPCHECK_DEBUG_TOKEN});report.appCheckDebugExchange=token.status;save();
 const headers={'X-Goog-Api-Key':config.SUBAKO_FIREBASE_API_KEY,'X-Firebase-AppId':config.SUBAKO_FIREBASE_APP_ID,
   Authorization:'Firebase '+signed.value.idToken,'x-goog-api-client':'gl-dart/5.1.0 fire/5.1.0'};
 if(process.env.SUBAKO_DEBUG_SHA1){headers['X-Android-Package']='id.mikiko.subako';headers['X-Android-Cert']=process.env.SUBAKO_DEBUG_SHA1.replaceAll(':','');}
 const endpoint=`https://firebasevertexai.googleapis.com/v1beta/projects/${report.project}/models/${report.model}`;
 try{
   const denied=await json(endpoint+':generateContent',{contents:[{parts:[{text:'Uji App Check, jawab singkat.'}]}],generationConfig:{maxOutputTokens:8}},headers,15000);
   report.missingAppCheck={status:denied.status,message:denied.value.error?.message??null};
   report.appCheckEnforcement=[401,403].includes(denied.status)&&/app.?check/i.test(denied.value.error?.message??'')?'VERIFIED':'NOT_VERIFIED';
 }catch(error){report.appCheckEnforcement='TIMEOUT';}save();
 const response=await fetch(endpoint+':streamGenerateContent?alt=sse',{method:'POST',headers:{'Content-Type':'application/json',...headers,'X-Firebase-AppCheck':token.value.token},
   body:JSON.stringify({contents:[{parts:[{text:'Dalam satu kalimat Bahasa Indonesia, jelaskan fungsi sensor tinggi air.'}]}],generationConfig:{maxOutputTokens:512,thinkingConfig:{thinkingLevel:'LOW'}}}),signal:AbortSignal.timeout(60000)});
 report.geminiStreamingStatus=response.status;save();
 if(!response.ok){const body=await response.json();report.geminiError=body.error?.message;save();return;}
 const reader=response.body.getReader();let buffer='';
 while(true){const {done,value}=await reader.read();if(done)break;buffer+=new TextDecoder().decode(value);if(buffer.includes('"text"')){report.geminiTextReceived=true;await reader.cancel();break;}}
 save();
}
main().then(()=>{
 report.passed=report.authentication===200 && report.authorizedSite===200 && report.unauthorizedSite===403 &&
   report.appCheckDebugExchange===200 && report.appCheckEnforcement==='VERIFIED' &&
   report.geminiStreamingStatus===200 && report.geminiTextReceived===true;
 if(!report.passed)process.exitCode=1;
}).catch(error=>{
 report.passed=false;report.geminiError=error.name==='TimeoutError'?'TIMEOUT':error.message;process.exitCode=1;
}).finally(()=>{save();console.log(JSON.stringify(report));});
