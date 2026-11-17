// Secure database-webhook receiver for Reach notifications.
// Deploy with --no-verify-jwt. Protect with REACH_WEBHOOK_SECRET in x-reach-hook header.
// Secrets: FCM_SERVICE_ACCOUNT_JSON, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
import { createClient } from 'npm:@supabase/supabase-js@2';

type ServiceAccount = {client_email:string;private_key:string;project_id:string};
const enc = new TextEncoder();
const b64url = (input:Uint8Array)=>btoa(Array.from(input, b=>String.fromCharCode(b)).join(''))
  .replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
function derFromPem(pem:string):Uint8Array {
  const raw=pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'');
  return Uint8Array.from(atob(raw),c=>c.charCodeAt(0));
}
async function googleAccessToken(sa:ServiceAccount):Promise<string> {
  const now=Math.floor(Date.now()/1000);
  const head=b64url(enc.encode(JSON.stringify({alg:'RS256',typ:'JWT'})));
  const payload=b64url(enc.encode(JSON.stringify({iss:sa.client_email,
    scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',
    iat:now,exp:now+3000})));
  const key=await crypto.subtle.importKey('pkcs8',derFromPem(sa.private_key.replace(/\\n/g,'\n')).buffer,
     {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const sig=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,enc.encode(`${head}.${payload}`));
  const jwt=`${head}.${payload}.${b64url(new Uint8Array(sig))}`;
  const response=await fetch('https://oauth2.googleapis.com/token',{
    method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:jwt})});
  if(!response.ok)throw new Error('FCM token exchange failed');
  const data=await response.json();return data.access_token;
}
Deno.serve(async req=>{
  if(req.method!=='POST')return new Response('method not allowed',{status:405});
  const expected=Deno.env.get('REACH_WEBHOOK_SECRET');
  if(!expected||req.headers.get('x-reach-hook')!==expected)return new Response('unauthorized',{status:401});
  try {
    const body=await req.json();
    const alertId=body?.record?.id;
    if(typeof alertId!=='string')return new Response('bad body',{status:400});
    const url=Deno.env.get('SUPABASE_URL')!;
    const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      {auth:{persistSession:false,autoRefreshToken:false}});
    // Always fetch canonical alert from DB, never trust webhook-supplied target/body.
    const {data:alert,error:aerr}=await admin.from('alerts').select('user_id,title,body').eq('id',alertId).single();
    if(aerr||!alert)return new Response('alert not found',{status:404});
    const {data:profile}=await admin.from('profiles').select('notify_on,suspended').eq('id',alert.user_id).single();
    if(!profile?.notify_on||profile.suspended)return Response.json({sent:0,skipped:true});
    const {data:tokens}=await admin.from('device_tokens').select('token').eq('user_id',alert.user_id).limit(20);
    if(!tokens?.length)return Response.json({sent:0});
    const sa=JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!) as ServiceAccount;
    const access=await googleAccessToken(sa);
    let sent=0;
    for(const t of tokens){
      const response=await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(sa.project_id)}/messages:send`,{
       method:'POST',headers:{authorization:`Bearer ${access}`,'content-type':'application/json'},
       body:JSON.stringify({message:{token:t.token,notification:{title:alert.title,body:alert.body},
         android:{priority:'high',notification:{channel_id:'reach_updates'}}}})});
      if(response.ok){sent++;}else if(response.status===404||response.status===400){
        await admin.from('device_tokens').delete().eq('user_id',alert.user_id).eq('token',t.token);
      }
    }
    return Response.json({sent});
  }catch(err){console.error('Push webhook error',err);return Response.json({error:'delivery failed'},{status:500});}
});
