import test from 'node:test';
import assert from 'node:assert/strict';
import { csvDocument } from '../src/lib/csv.ts';
test('CSV preserves UTF-8 text, quotes, commas and embedded newlines',()=>{
 assert.equal(csvDocument(['Label','Note'],[['₱500','A,"B"\nC']]),'\uFEFF"Label","Note"\r\n"₱500","A,""B""\nC"\r\n');
});
test('untrusted formulas including whitespace/control prefixes are inert spreadsheet text',()=>{
 for(const input of ['=1+1','+cmd','-cmd','@SUM(A1)','\t=1','\r=1','  =1','\uFEFF=1']) assert.ok(csvDocument(['Value'],[[input]]).includes('"\''+input+'"'));
 assert.ok(csvDocument(['Amount'],[[-10]]).includes('"-10"'));
});
test('CSV rejects invalid rows or non-finite numeric totals',()=>{
 assert.throws(()=>csvDocument(['One'],[['a','b']]));
 assert.throws(()=>csvDocument(['Amount'],[[Infinity]]));
});
