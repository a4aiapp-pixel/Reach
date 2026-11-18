// Delete the authenticated member's own chat files before account removal.
// No user-supplied owner id is trusted. The caller is validated by GoTrue.
import { createClient } from 'npm:@supabase/supabase-js@2.57.0';

const respond=(data:unknown,status=200)=>Response.json(data,{
  status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff'}
});

Deno.serve(async(req:Request)=>{
  if(req.method!=='POST')return respond({error:'Method not allowed'},405);
  const bearer=req.headers.get('authorization')??'';
  if(!bearer.startsWith('Bearer ')||bearer.length>4200){
    return respond({error:'Unauthorized'},401);
  }
  const url=Deno.env.get('SUPABASE_URL');
  const secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!secret)return respond({error:'Service temporarily unavailable'},503);
  const admin=createClient(url,secret,{
    auth:{persistSession:false,autoRefreshToken:false}
  });
  try {
    const {data,error}=await admin.auth.getUser(bearer.substring(7));
    if(error||!data?.user?.id)return respond({error:'Unauthorized'},401);
    const userId=data.user.id;
    // No physical deletion occurs until all matching storage objects
    // are enumerated. The private metadata is the source of truth.
    let removed=0;
    for(;;){
      const {data:rows,error:dbError}=await admin.from('chat_attachments')
        .select('id,object_path').eq('sender_id',userId).order('created_at',{ascending:true})
        .limit(50);
      if(dbError)throw dbError;
      if(!rows||rows.length===0)break;
      const paths=rows.map((r:{object_path:string})=>r.object_path);
      const {error:storageError}=await admin.storage.from('reach-chat').remove(paths);
      if(storageError)throw storageError;
      const ids=rows.map((r:{id:string})=>r.id);
      const {error:deleteError}=await admin.from('chat_attachments')
        .delete().eq('sender_id',userId).in('id',ids);
      if(deleteError)throw deleteError;
      removed+=rows.length;
      if(removed>2000)throw Error('Too many objects. Contact support.');
    }
    return respond({removed});
  }catch(e){
    // Never put secrets, paths or raw provider errors in public output.
    console.error('Account attachment cleanup failed',e instanceof Error?e.name:'error');
    return respond({error:'Could not finish removing files. Try again or contact support.'},503);
  }
});
