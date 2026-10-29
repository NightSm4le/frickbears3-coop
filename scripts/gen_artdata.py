#!/usr/bin/env python3
# regenerates gml/coop/gml_GlobalScript_CoopArtData.gml from coop_art/*.png
import base64, glob, os
os.chdir(os.path.join(os.path.dirname(__file__), '..'))
out = ['// ===== 0.6.3: draft co-op art embedded in data.win (generated from coop_art/*.png by scripts/gen_artdata.py) =====',
       '// coop_art_get() uses these when <game>/coop_art/<key>.png is missing (the tester had no coop_art folder in 0.6.2).',
       'function coop_art_embedded(_key)', '{', '    switch (_key)', '    {']
for f in sorted(glob.glob('coop_art/*.png')):
    out.append('        case "%s": return "%s";' % (os.path.basename(f)[:-4], base64.b64encode(open(f, 'rb').read()).decode()))
out += ['    }', '    return "";', '}', '']
open('gml/coop/gml_GlobalScript_CoopArtData.gml', 'w').write('\n'.join(out))
