from pathlib import Path
from PIL import Image, ImageDraw
import json
root=Path(__file__).resolve().parents[1]
palette={'paper':'F4E7CD','wood':'D7B98A','brown':'754B36','green':'789C79','gold':'E7B96B','star':'7775B4','text':'35291F','muted':'705E4C','title':'66442F','danger':'984B3E'}
(root/'resources/ui/river_palette.json').write_text(json.dumps({'theme':'河湾手作 · 星辉田园','palette':palette,'type':{'title':24,'body':18,'caption':16,'number':19},'touch_design_px':48,'nine_patch_margin':8},ensure_ascii=False,indent=2)+'\n')
def patch(name,fill,edge,shine,pressed=False,transparent=False):
 im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im)
 # 阶梯角、三层木框与稀疏铆点；边带通过九宫格保留原像素宽度。
 d.polygon([(3,0),(20,0),(20,1),(22,1),(22,3),(23,3),(23,20),(22,20),(22,22),(20,22),(20,23),(3,23),(3,22),(1,22),(1,20),(0,20),(0,3),(1,3),(1,1),(3,1)],fill='#'+edge)
 d.rectangle((3,2,20,21),fill='#'+shine);d.rectangle((2,3,21,20),fill='#'+shine)
 d.rectangle((4,4,19,19),fill='#'+edge)
 d.rectangle((5,5,18,18),fill=(0,0,0,0) if transparent else '#'+fill)
 if transparent:
  d.rectangle((4,4,19,19),fill=(0,0,0,0))
 else:
  d.line((5,5,18,5),fill='#'+shine)
  for x,y in [(3,3),(20,3),(3,20),(20,20)]:d.point((x,y),fill='#'+edge)
  for x in [8,15]:d.point((x,2),fill='#'+fill)
  if pressed:d.line((5,5,18,5),fill='#'+edge)
 im.save(root/f'assets/ui/river/{name}.png')
patch('paper',palette['paper'],palette['brown'],'ECD7AD')
patch('secondary','EBD8B5','AA805B','FFF1D5')
patch('button','E3C89F',palette['brown'],'F9E6BE')
patch('hover','EED8B4','93623E','FFF1D0')
patch('pressed',palette['gold'],palette['brown'],'F2D698',True)
patch('disabled','D7CBB4','A99A81','E4D9C2')
patch('focus',palette['paper'],palette['star'],'B8ADDB',transparent=True)
patch('selected','EAC78B','97683B','FFF0BD')
patch('nature','C0D2AC','657D56','E1EBD1')
patch('star','DDD8ED','7775B4','F4EEFC')
patch('danger','E4B69D','984B3E','F8DAC1')
patch('track','D4C3A5','AB8C67','E8D7B5')
patch('fill','A1BC80','657D56','D6E3B8')
# 小型原创状态图标，保持与现有16-32px图标比例一致。
for name,color in [('date','B68B5C'),('weather','E7B96B'),('coin','D6A44F'),('stamina','789C79'),('task','7775B4')]:
 im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
 if name=='date':
  d.rectangle((2,3,13,13),fill='#F4E7CD',outline='#754B36');d.rectangle((3,4,12,6),fill='#'+color);d.point((5,9),fill='#754B36');d.point((9,9),fill='#754B36')
 elif name=='weather':
  d.rectangle((5,4,10,10),fill='#'+color);d.rectangle((3,6,12,8),fill='#'+color);d.line((7,1,7,2),fill='#754B36');d.line((7,12,7,14),fill='#754B36')
 elif name=='coin':
  d.ellipse((3,2,12,13),fill='#'+color,outline='#754B36');d.line((7,5,7,10),fill='#F4E7CD')
 elif name=='stamina':d.polygon([(8,1),(3,9),(7,9),(6,15),(13,6),(9,6)],fill='#'+color)
 else:
  d.rectangle((3,2,12,13),fill='#F4E7CD',outline='#754B36');d.line((5,5,10,5),fill='#'+color);d.line((5,8,10,8),fill='#'+color);d.line((5,11,8,11),fill='#'+color)
 im.save(root/f'assets/ui/river/icon_{name}.png')
names=['paper','secondary','button','hover','pressed','disabled','focus','selected','nature','star','danger','track','fill']
lines=['[gd_resource type="Theme" load_steps=28 format=3]','']
for n in names:lines.append(f'[ext_resource type="Texture2D" path="res://assets/ui/river/{n}.png" id="{n}"]')
lines.append('[ext_resource type="FontFile" path="res://assets/ui/fonts/NotoSansCJK-Regular.ttc" id="font"]')
for n in names:
 lines+=['',f'[sub_resource type="StyleBoxTexture" id="{n}"]',f'texture = ExtResource("{n}")']
 for side in ['left','top','right','bottom']:
  lines.append(f'texture_margin_{side} = 8.0')
  lines.append(f'content_margin_{side} = '+('16.0' if side in ['left','right'] else '8.0'))
lines+=['','[resource]','default_font = ExtResource("font")','default_font_size = 18']
def col(hex):return 'Color('+', '.join(str(round(int(hex[i:i+2],16)/255,6)) for i in [0,2,4])+', 1)'
for type in ['Label','Button','CheckButton','CheckBox','OptionButton','Window','ConfirmationDialog']:
 lines.append(f'{type}/colors/font_color = '+col(palette['text']))
for state in ['hover','pressed','focus']:
 lines.append(f'Button/colors/font_{state}_color = '+col(palette['text']))
lines.append('Button/colors/font_disabled_color = '+col('8A7D68'))
for st,n in [('normal','button'),('hover','hover'),('pressed','pressed'),('disabled','disabled'),('focus','focus')]:lines.append(f'Button/styles/{st} = SubResource("{n}")')
for t,key,n in [('PanelContainer','panel','paper'),('PopupPanel','panel','paper'),('Window','embedded_border','paper'),('ProgressBar','background','track'),('ProgressBar','fill','fill')]:lines.append(f'{t}/styles/{key} = SubResource("{n}")')
for t in ['VScrollBar','HScrollBar']:
 for key,n in [('scroll','track'),('grabber','button'),('grabber_highlight','selected'),('grabber_pressed','nature')]:lines.append(f'{t}/styles/{key} = SubResource("{n}")')
lines+=['Label/constants/line_spacing = 4','HBoxContainer/constants/separation = 10','VBoxContainer/constants/separation = 10','Window/constants/title_height = 28','Window/font_sizes/title_font_size = 20','Window/colors/title_color = '+col(palette['title'])]
(root/'resources/ui/river_theme.tres').write_text('\n'.join(lines)+'\n')
