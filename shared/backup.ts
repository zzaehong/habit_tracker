import {z} from 'zod';
import {entitySchema,type Entity} from './model';
export const backupSchema=z.object({format:z.literal('chagok'),version:z.literal(1),exportedAt:z.string(),entities:z.array(entitySchema)}).superRefine((v,ctx)=>{if(new Set(v.entities.map(e=>e.id)).size!==v.entities.length)ctx.addIssue({code:'custom',message:'중복 ID가 있습니다.'})});
export function makeBackup(entities:Entity[]){return {format:'chagok' as const,version:1 as const,exportedAt:new Date().toISOString(),entities}}
export function csv(rows:unknown[][]){return '\ufeff'+rows.map(row=>row.map(v=>{let s=v===undefined||v===null?'':String(v);if(/^[=+@\-]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"'}).join(',')).join('\r\n')}
export function comparable(e:Entity){const {version,updatedAt,...rest}=e;return JSON.stringify(rest)}
