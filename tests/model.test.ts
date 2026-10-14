import {describe,it,expect} from 'vitest';
import {newActivity,isDue,weekStart,pace,entrySchema,scheduleAt,weeklyCount,type Entry} from '../shared/model';
describe('일정과 데이터',()=>{
 it('월요일 기준 주 경계',()=>{expect(weekStart('2026-10-18')).toBe('2026-10-12')});
 it('N일 간격과 적용일 이전 일정 보존',()=>{const a=newActivity('running');a.schedule=[{effective:'2026-10-01',value:{type:'interval',start:'2026-10-01',interval:3,count:3,weekdays:[]}},{effective:'2026-10-15',value:{type:'daily',start:'2026-10-15',interval:1,count:3,weekdays:[]}}];expect(isDue(a,'2026-10-04')).toBe(true);expect(isDue(a,'2026-10-05')).toBe(false);expect(scheduleAt(a,'2026-10-04')?.type).toBe('interval')});
 it('누락 거리로 페이스를 생성하지 않음',()=>{expect(pace({custom:{},seconds:300})).toBeUndefined();expect(pace({custom:{},seconds:300,distance:0})).toBeUndefined();expect(pace({custom:{},seconds:300,distance:1})).toBe(300)});
 it('체감 강도 범위 검사',()=>{expect(entrySchema.safeParse({}).success).toBe(false)});
 it('주간 횟수는 수행일 수',()=>{const a=newActivity('study');const rows=[{activityId:a.id,date:'2026-10-14',done:true},{activityId:a.id,date:'2026-10-14',done:true}] as Entry[];expect(weeklyCount(a,'2026-10-14',rows)).toBe(1)})
});
