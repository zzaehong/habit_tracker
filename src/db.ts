import Dexie, {type Table} from 'dexie';
import {type Entity,type Operation,type Conflict,type Activity,entitySchema,newActivity,now} from '../shared/model';
class Store extends Dexie {
 entities!:Table<Entity,string>;outbox!:Table<Operation,string>;conflicts!:Table<Conflict,string>;meta!:Table<{key:string;value:any},string>;blobs!:Table<{id:string;blob:Blob},string>;
 constructor(){super('chagok');this.version(1).stores({entities:'id,type',outbox:'id',conflicts:'id',meta:'key',blobs:'id'})}
}
export const db=new Store();
export async function save(entity:Entity){const valid=entitySchema.parse({...entity,updatedAt:now()});await db.transaction('rw',db.entities,db.outbox,async()=>{await db.entities.put(valid);await db.outbox.add({id:crypto.randomUUID(),baseVersion:entity.version,entity:valid})});window.dispatchEvent(new Event('local-change'));return valid}
export async function remove(e:Entity){await save({...e,deleted:true})}
export async function initialize(){await db.transaction('rw',db.entities,db.outbox,db.meta,async()=>{if(await db.meta.get('initialized'))return;for(const k of ['reading','running','weights','meal','tutoring','study'] as const){const a=newActivity(k);a.id='default-'+k;await db.entities.put(a);await db.outbox.add({id:crypto.randomUUID(),baseVersion:0,entity:a})}await db.meta.put({key:'initialized',value:true})});navigator.storage?.persist?.().catch(()=>{})}
export async function getMeta(key:string){return (await db.meta.get(key))?.value}
export async function setMeta(key:string,value:any){await db.meta.put({key,value})}
export async function saveDefinition(a:Activity){await save(a)}
