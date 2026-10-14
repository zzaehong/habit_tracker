import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {newActivity,today} from '../shared/model';
import {prompt,outputSchema,validateAI} from '../shared/ai';
const activities=(['reading','running','weights','meal','tutoring','study'] as const).map(k=>newActivity(k));activities.find(a=>a.kind==='study')!.fields=[{id:'focus',name:'집중도',type:'number',unit:'',options:[],aggregate:'mean',hidden:false}];
const cases=JSON.parse(readFileSync('tests/ai-cases.json','utf8')) as string[];const results=[];
try{await fetch('http://127.0.0.1:11434/api/tags',{signal:AbortSignal.timeout(2000)})}catch{console.error('NOT RUN: 로컬 Ollama 서버에 연결할 수 없습니다.');process.exit(2)}
for(const text of cases){const start=Date.now();try{const res=await fetch('http://127.0.0.1:11434/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({model:process.env.OLLAMA_MODEL||'qwen3:4b',stream:false,think:false,format:outputSchema,messages:[{role:'user',content:prompt({text,date:today()},activities,[])}]}),signal:AbortSignal.timeout(120000)});const body=await res.json() as any;const result=validateAI(JSON.parse(body.message.content),activities);results.push({text,status:'SCHEMA PASS; 의미 정확도 수동 검토 필요',ms:Date.now()-start,result})}catch(e){results.push({text,status:'FAIL',error:String(e)})}}
mkdirSync('runtime/evidence',{recursive:true});const out='runtime/evidence/ai-'+Date.now()+'.json';writeFileSync(out,JSON.stringify(results,null,2));console.log(out);
