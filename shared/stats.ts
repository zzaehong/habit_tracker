import {type Entry,type Activity,addDays,isDue,weekStart,scheduleAt,weeklyCount} from './model';
export function values(entries:Entry[],key:string){return entries.map(e=>(e.data as any)[key]).filter((v):v is number=>typeof v==='number'&&Number.isFinite(v))}
export function sum(v:number[]){return v.length?v.reduce((a,b)=>a+b,0):undefined}
export function mean(v:number[]){return v.length?v.reduce((a,b)=>a+b,0)/v.length:undefined}
export function days(from:string,to:string){const out:string[]=[];for(let d=from;d<=to&&out.length<3660;d=addDays(d,1))out.push(d);return out}
export function achievement(a:Activity,entries:Entry[],from:string,to:string){let expected=0,done=0;const weeks=new Set<string>();for(const date of days(from,to)){const s=scheduleAt(a,date);if(!s||date<s.start)continue;if(s.type==='weekly'){const w=weekStart(date);if(weeks.has(w))continue;weeks.add(w);expected+=s.count;done+=Math.min(s.count,weeklyCount(a,date,entries));continue}if(s.type==='once'&&date!==s.start)continue;if(isDue(a,date,[])){expected++;if(entries.some(e=>!e.deleted&&e.done&&e.activityId===a.id&&e.date===date))done++}}return {done,expected}}
