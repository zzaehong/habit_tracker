import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {existsSync} from 'node:fs';
import path from 'node:path';
import {z} from 'zod';
import type {Draft,Activity} from '../shared/model';
import {parseNRC,mergeCaptures} from '../shared/nrc';
import {Repository} from './store';
const exec=promisify(execFile);
const lineSchema=z.array(z.object({text:z.string(),confidence:z.number(),x:z.number(),y:z.number(),width:z.number(),height:z.number()}));
export function captureProcessor(repo:Repository,directory:string){return async(draft:Draft)=>{if(!draft.attachments.length||draft.attachments.length>5)throw Error('캡처는 1–5장 필요합니다.');const binary=path.resolve(directory,'ocr');if(!existsSync(binary))throw Error('맥미니에서 npm run ocr:build를 먼저 실행하세요.');const results=[];const original=[];for(const id of draft.attachments){const a=repo.get(id);if(a?.type!=='attachment'||a.deleted)throw Error('첨부 업로드 대기 또는 삭제된 이미지');const file=path.resolve(directory,'attachments',a.hash);if(!existsSync(file))throw Error('첨부 파일 업로드가 완료되지 않았습니다.');const {stdout}=await exec(binary,[file],{timeout:60000,maxBuffer:2*1024*1024});const lines=lineSchema.parse(JSON.parse(stdout));const parsed=parseNRC(lines);results.push(parsed);original.push({attachment:id,lines,units:parsed.units})}const merged=mergeCaptures(results);const activities=repo.all().filter((a):a is Activity=>a.type==='activity'&&!a.deleted&&a.kind==='running');const activity=activities.find(a=>draft.activityId===a.id)||activities[0];if(!activity)throw Error('러닝 활동이 없습니다.');if(repo.all().some(e=>e.type==='entry'&&!e.deleted&&e.date===draft.date&&e.definition.kind==='running'&&e.data.distance===merged.data.distance&&e.data.seconds===merged.data.seconds))merged.questions.push('같은 날짜에 거리·시간이 같은 러닝이 있습니다. 중복인지 확인하세요.');return {records:[{activityId:activity.id,date:draft.date,data:merged.data,questions:merged.questions}],ocr:JSON.stringify(original)}}}
