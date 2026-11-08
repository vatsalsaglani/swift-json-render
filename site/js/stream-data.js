/* SpecStream transcripts for the streaming demo. One RFC 6902 patch per line (JSONL), as upstream.
   Scenario 1 includes an out-of-order orphan and one malformed line. Scenario 2 grows a chart point by point. */
(function (g) {
  'use strict';
  var JR = (g.JR = g.JR || {});
  function line(o) { return JSON.stringify(o); }
  var add = function (path, value) { return line({ op: 'add', path: path, value: value }); };

  var tests = [
    add('/root', 'card'),
    add('/elements/card', { type: 'Card', props: { title: 'Failing tests by suite', description: 'Streamed one patch at a time' }, children: ['stats', 'tabs'] }),
    add('/elements/row-open', { type: 'Button', props: { label: 'Open', size: 'sm' }, on: { press: { action: 'open_file', params: { path: { $item: 'file' } } } } }),
    add('/elements/stats', { type: 'Grid', props: { columns: 3 }, children: ['s1', 's2', 's3'] }),
    add('/elements/s1', { type: 'Stat', props: { label: 'Failing', value: { $state: '/failing' }, delta: '+3', intent: 'risk' } }),
    add('/elements/s2', { type: 'Stat', props: { label: 'Suites', value: { $state: '/suiteCount' } } }),
    add('/elements/s3', { type: 'Stat', props: { label: 'Wall time', value: '41', unit: 's', delta: '−6', intent: 'good' } }),
    add('/elements/tabs', { type: 'Tabs', props: { tabs: [{ value: 'suites', label: 'By suite' }, { value: 'slow', label: 'Slowest' }], value: { $bindState: '/tab' } }, children: ['table'] }),
    '{"op":"add","path":"/elements/table","value":{"type":"Table","props":{"columns":[{"key":"name"',
    add('/elements/table', { type: 'Table', props: { columns: [{ key: 'name', label: 'Suite' }, { key: 'failed', label: 'Failed', align: 'right' }] }, children: ['row-open'], repeat: { statePath: '/suites', key: 'name' } }),
    add('/state', { tab: 'suites', failing: 7, suiteCount: 3, suites: [{ name: 'CanvasBoardStateTests', failed: 4, file: 'Tests/CanvasBoardStateTests.swift' }, { name: 'VoiceSessionTests', failed: 2, file: 'Tests/VoiceSessionTests.swift' }, { name: 'MDXBlockScannerTests', failed: 1, file: 'Tests/MDXBlockScannerTests.swift' }] }),
    line({ op: 'replace', path: '/elements/card/props/description', value: 'Stream complete. Validated and frozen.' })
  ];

  var wall = [12, 18, 15, 22, 28, 26, 40, 37, 33, 58, 52, 46, 44, 49];
  var chart = [
    add('/root', 'card'),
    add('/elements/card', { type: 'Card', props: { title: 'Wall time, run by run', description: 'Points arrive while the model works' }, children: ['chart', 'caption'] }),
    add('/elements/chart', { type: 'LineChart', props: { x: 'run', y: 'secs', unit: 's', curve: 'monotone', points: 'always' } }),
    add('/elements/chart/props/data', [{ run: 'r1', secs: wall[0] }])
  ];
  for (var i = 1; i < wall.length; i++) chart.push(add('/elements/chart/props/data/-', { run: 'r' + (i + 1), secs: wall[i] }));
  chart.push(line({ op: 'replace', path: '/elements/chart/props/data/9/secs', value: 36 }));
  chart.push(add('/elements/caption', { type: 'Text', props: { text: '14 runs. The spike at r10 was a bad sample and the model corrected it.', variant: 'muted' } }));

  JR.streams = [
    { id: 'tests', title: 'Failing tests card', blurb: 'Skeletons for children that have not arrived. A button that arrives before its table. One malformed line, journaled and skipped.', lines: tests, domain: false },
    { id: 'chart', title: 'Growing chart', blurb: 'A line chart gets one point per patch. The y-domain only grows while the stream runs, so the chart never jumps. It settles at the end.', lines: chart, domain: true }
  ];
})(typeof globalThis !== 'undefined' ? globalThis : this);
