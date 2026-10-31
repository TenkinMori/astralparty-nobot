import sys, os
args = sys.argv[1:]
tools, orig, patched, out = args[0], args[1], args[2], args[3]
sys.path.insert(0, tools)
import bundle
bundle.write_dll(orig, open(patched, 'rb').read(), out, 'AstralParty.Runtime.dll')
print('ok %d' % os.path.getsize(out))