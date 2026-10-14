import {it,expect} from 'vitest';
import {zipSync,unzipSync,strToU8,strFromU8} from 'fflate';
import {makeBackup,backupSchema,csv} from '../shared/backup';
import {newActivity} from '../shared/model';
import {mean,sum,achievement} from '../shared/stats';
it('JSON과 이미지 포함 ZIP 왕복',()=>{const backup=makeBackup([newActivity('running')]);const image=new Uint8Array([1,2,3]);const zipped=zipSync({'records.json':strToU8(JSON.stringify(backup)),'attachments/example':image});const files=unzipSync(zipped);expect(backupSchema.parse(JSON.parse(strFromU8(files['records.json'])))).toEqual(backup);expect(files['attachments/example']).toEqual(image)});
it('CSV 수식 주입 및 쉼표 처리',()=>{expect(csv([['=cmd','a,b','a"b',undefined]])).toContain('"\'=cmd","a,b","a""b",""')});
it('누락값은 0 평균을 만들지 않음',()=>{expect(mean([])).toBeUndefined();expect(sum([])).toBeUndefined()});
