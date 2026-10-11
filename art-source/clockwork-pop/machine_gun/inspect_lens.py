import bpy
from pathlib import Path
p=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(p/'cp_machine_gun.blend'))
im=bpy.data.images.get('Generated sapphire jewel')
print('PIXELS',list(im.pixels[(200*256+90)*4:(200*256+90)*4+4]))
im.filepath_raw=str(p/'optic_generated.png');im.file_format='PNG';im.save()
