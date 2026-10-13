import sys,json,tempfile
from pathlib import Path
sys.path.insert(0,str(Path.cwd()))
sys.path.insert(0,str(Path.cwd()/'tests'))
from test_successor_evidence import ControlFixture
from research_pipeline.successor_evidence import PinnedControlContext
from research_pipeline.stage14 import ResearchRunCoordinator
with tempfile.TemporaryDirectory() as tmp:
 f=ControlFixture(Path(tmp));c=ResearchRunCoordinator(control_context=PinnedControlContext(f.directory,f.pin))
 original=c.authorize
 def altered(manifest,authorization):
  (f.directory/'control.json').write_bytes(b'{}')
  return original(manifest,authorization)
 c.authorize=altered
 try:c.render_bundle(f.manifest,f.authorization)
 except ValueError as exc:
  print(json.dumps(dict(reason=str(exc),type=type(exc).__name__,stage=getattr(exc,'stage',None),detail=getattr(exc,'detail',None),rendered_bundle=False)))
 else:raise AssertionError('Unexpected rendered bundle')
