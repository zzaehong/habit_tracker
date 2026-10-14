import {readFileSync,writeFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
const files=['/','/manifest.webmanifest','/icon.svg','/icon-192.png','/icon-512.png',...readdirSync('dist/assets').map(f=>'/assets/'+f)];
const version=createHash('sha256').update(readFileSync('dist/index.html')).update(files.join('|')).digest('hex').slice(0,12);
writeFileSync('dist/sw.js',`self.__PRECACHE=${JSON.stringify(files)};self.__CACHE="chagok-shell-${version}";\n`+readFileSync('public/sw.js','utf8'));
