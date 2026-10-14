import {it,expect} from 'vitest';
import {parseNRC,mergeCaptures} from '../shared/nrc';
const lines=(...texts:string[])=>texts.map(text=>({text,confidence:.95}));
it('거리 시간 심박수 케이던스 표시값 추출',()=>{const r=parseNRC(lines('거리 5.00 km','시간 32:00','평균 심박수 145 bpm','케이던스 176 spm','평균 페이스 6:24 /km'));expect(r.data.distance).toBe(5);expect(r.data.seconds).toBe(1920);expect(r.data.heartRate).toBe(145);expect(r.data.cadence).toBe(176);expect(r.data.reportedPace).toBe(384)});
it('마일 변환, 누락 강도와 심박수 미생성',()=>{const r=parseNRC(lines('Distance 2 miles','Time 20:00'));expect(r.data.distance).toBeCloseTo(3.218688);expect(r.data.heartRate).toBeUndefined();expect(r.data.intensity).toBeUndefined();expect(r.units.distance).toBe('mi')});
it('캡처 값 충돌을 덮어쓰지 않음',()=>{const r=mergeCaptures([parseNRC(lines('거리 5 km')),parseNRC(lines('거리 6 km'))]);expect(r.data.distance).toBeUndefined();expect(r.questions.join()).toContain('캡처 간 값')});
it('계산 페이스 불일치와 낮은 확신 알림',()=>{const r=parseNRC([...lines('거리 5 km','시간 30:00','페이스 7:00 /km'),{text:'?',confidence:.1}]);expect(r.questions.join()).toContain('페이스');expect(r.questions.join()).toContain('확신')});
it('라벨 위 숫자를 좌표로 대응',()=>{const r=parseNRC([{text:'5.00',confidence:.9,x:.1,y:.8,width:.2,height:.05},{text:'거리',confidence:.9,x:.1,y:.73,width:.2,height:.03},{text:'32:00',confidence:.9,x:.6,y:.8,width:.2,height:.05},{text:'시간',confidence:.9,x:.6,y:.73,width:.2,height:.03}]);expect(r.data.distance).toBe(5);expect(r.data.seconds).toBe(1920)});
