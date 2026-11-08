#!/usr/bin/env python3
"""Recreate six editable SVG UX wireframes and PNG previews. No network access needed."""
from pathlib import Path
import html
import math
import cairosvg
BASE=Path(__file__).resolve().parents[1]
SVGS=BASE/'assets/ux/wireframes'
PNGS=BASE/'assets/ux/previews'
SVGS.mkdir(parents=True,exist_ok=True)
PNGS.mkdir(parents=True,exist_ok=True)
W,H=1440,900
bg='#07111b'; panel='#10202e'; raised='#173243'; border='#2e5267'; fg='#e9f4fa'; mute='#98afbf'; cyan='#58d9eb'; amber='#f3b66a'; green='#78dfaf'; red='#ee807e'
keys=['01_总部','02_矿区竞拍','03_太空采矿','04_火箭装配','05_市场交易','06_本轮结算']
nav=['总部','矿区竞拍','太空采矿','火箭装配','市场交易','本轮结算']

def esc(s):return html.escape(str(s))
def shape_rect(x,y,w,h,c,stroke='none',radius=9,sw=1):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{c}" stroke="{stroke}" stroke-width="{sw}"/>'
def text(x,y,t,size=18,c=fg,weight=400,anchor='start',spacing=0):return f'<text x="{x}" y="{y}" font-family="Noto Sans CJK SC,Microsoft YaHei,sans-serif" font-size="{size}" fill="{c}" font-weight="{weight}" letter-spacing="{spacing}" text-anchor="{anchor}">{esc(t)}</text>'
def line(x1,y1,x2,y2,c=border,w=1,dash=''):return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{w}" stroke-dasharray="{dash}"/>'
def circle(x,y,r,c,opacity=1,stroke='none',sw=1):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" fill-opacity="{opacity}" stroke="{stroke}" stroke-width="{sw}"/>'
def button(x,y,w,label,primary=False):return shape_rect(x,y,w,42,cyan if primary else raised,cyan if primary else border,6)+text(x+w/2,y+28,label,15,bg if primary else fg,700,'middle')
def panel_title(x,y,title,sub=None):
 z=text(x,y,title,21,fg,700)
 if sub:z+=text(x,y+26,sub,13,mute)
 return z

def shell(title,desc,active):
 a=[f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',shape_rect(0,0,W,H,bg,radius=0),shape_rect(0,0,W,71,panel,radius=0),text(24,43,'ROCKET PROSPECTORS  /  星矿大亨',21,amber,700)]
 for i,n in enumerate(nav):
  x=360+i*144
  if i==active:a.append(shape_rect(x,14,133,43,raised,cyan,7))
  a.append(text(x+66,42,n,15,cyan if i==active else mute,600,'middle'))
 a += [text(1402,43,'40,000 Cr',16,green,700,'end'),text(30,119,title,31,fg,700),text(31,149,desc,15,mute),shape_rect(0,842,W,58,panel,radius=0),text(27,877,'下一步：先完成当前页面的关键决策',15,mute),text(1413,877,'UX V1.0 · 可编辑线框图 / 演示数据',13,amber,400,'end')]
 return a

def close(a,name):
 a.append('</svg>')
 p=SVGS/(name+'.svg')
 p.write_text('\n'.join(a),encoding='utf-8')
 png=PNGS/(name+'.png')
 cairosvg.svg2png(url=str(p),write_to=str(png),output_width=960,output_height=600)
 return png

# 01 HQ
A=shell('星际总部','局外决策中心：科技、竞拍、贷款与股权；突出单一主行动，而非信息洪水',0)
A += [shape_rect(30,181,912,424,raised,border),text(66,224,'晨曦星域 / 拓荒者计划',17,cyan,700),text(66,294,'从一座发射基地，',42,fg,700),text(66,351,'建立你的矿业航线。',42,fg,700),text(66,406,'竞拍矿区 → 太空勘探 → 自动采矿 → 火箭运输 → 市场获利',17,mute),button(66,478,250,'开始矿区竞拍  →',True),button(337,478,217,'参观装配车间'),shape_rect(975,181,435,424,panel,border),panel_title(1004,222,'本轮战略目标','第一阶段只保留一条明确任务'),text(1005,314,'01   获得第一处采矿权',20,fg),line(1000,338,1382,338),text(1005,382,'02   发射探测器发现矿体',20,mute),line(1000,409,1382,409),text(1005,451,'03   运回矿石并完成交易',20,mute),text(33,650,'总部设施 / 次要功能在独立空间中，不打断本轮经营',17,mute)]
for i,(n,sub) in enumerate([('矿区竞拍','进入本轮拍卖'),('科技中心','升级采矿与火箭'),('银行与情报','贷款和特殊交易'),('星域股权','长期战役胜利条件')]):
 x=30+i*350;A += [shape_rect(x,674,331,141,panel,border),text(x+19,711,n,20,amber,700),text(x+19,744,sub,14,mute),text(x+19,785,'进入  →' if i==0 else '后续阶段开放',13,cyan if i==0 else mute)]
close(A,keys[0])
# 02 Auction
A=shell('矿区经营权拍卖','资源储量未知：在竞拍价格、勘探置信度和剩余启动资金之间权衡',1)
for i,(n,lot,info,risk,price) in enumerate([('青岚碎星带','F-01','富铁钛 · 估算可信度 65%','低风险','7,600 Cr'),('赤曜外缘','F-02','高价晶硅 · 估算可信度 42%','高波动','11,200 Cr'),('霜环碎冰区','F-03','富水冰 · 估算可信度 30%','低温风险','5,900 Cr')]):
 x=30+i*468; selected=i==0
 A += [shape_rect(x,190,448,491,raised if selected else panel,cyan if selected else border,10,2 if selected else 1),text(x+26,232,'◆ 矿区 '+lot,15,cyan,700),text(x+26,284,n,29,fg,700),line(x+26,306,x+420,306),text(x+26,353,info,17,mute),text(x+26,389,'环境风险：'+risk,16,mute),text(x+26,469,'竞拍参考价',15,mute),text(x+26,510,price,31,amber,700),button(x+26,598,396,'已选中' if selected else '选择此矿区',selected)]
A += [shape_rect(30,705,1380,106,panel,border),text(53,750,'选中：F-01   /   此阶段先用固定成交价验证拍卖信息层级与确认过程',16,fg),button(994,738,377,'确认竞拍并进入星域  →',True)]
close(A,keys[1])
# 03 mining
A=shell('太空采矿 · 青岚碎星带','在太空场景中直接操作探测器、采矿设备与货船；右侧仅显示当前目标',2)
A += [shape_rect(30,184,982,574,'#081b29',border),shape_rect(1030,184,380,574,panel,border),text(55,220,'动态星域场景  /  从发射坞拖动探测器到天体',16,cyan,700)]
for i in range(80):
 x=48+(i*173+41)%930;y=247+(i*137+47)%435
 A.append(circle(x,y,0.8 if i%3 else 1.4,fg,.20+(i%3)*.12))
A += [line(147,651,358,385,cyan,1,'5 6'),line(147,651,730,357,cyan,1,'5 6'),circle(147,651,44,cyan,.1),circle(147,651,24,'#397f9e'),text(147,725,'探测器发射坞',15,fg,500,'middle')]
for x,y,r,n,col in [(357,380,48,'晶硅碎星 A-03',cyan),(729,350,37,'赤曜陨石 B-07',amber),(838,588,55,'冰质卫星 C-12','#b89bfa')]:
 A += [circle(x,y,r+16,col,.1),circle(x,y,r,'#344d5d' if col==cyan else '#594d49'),circle(x,y,r+12,'none',1,col,2),text(x,y+r+40,n,16,fg,500,'middle')]
A += [panel_title(1054,224,'目标：晶硅碎星 A-03','选择天体后刷新详情'),line(1054,277,1388,277),text(1055,316,'扫描：未完成',17,mute),text(1055,354,'采矿舱：未部署',17,mute),text(1055,394,'矿区库存：0 t',17,mute),button(1054,457,329,'1  发射探测器  ·  500 Cr',True),button(1054,515,329,'2  部署采矿舱'),button(1054,573,329,'3  发射运输火箭'),text(1055,678,'火箭：可回收轻型  /  点击修改',14,amber),text(1055,717,'操作反馈只出现在所选对象附近',13,mute)]
close(A,keys[2])
# 04 assembly
A=shell('火箭装配车间','拖动零件到对应插槽；自动吸附、实时反馈。支持预设蓝图与一键复用',3)
A += [button(30,178,205,'可回收轻型',True),button(250,178,199,'一次性轻型'),text(477,207,'当前蓝图：可回收轻型火箭',16,amber),shape_rect(30,240,322,555,panel,border),shape_rect(373,240,647,555,'#081b28',border),shape_rect(1041,240,369,555,panel,border),panel_title(54,282,'可拖拽组件仓库','每类先做两种，不增加物理模拟')]
parts=['标准引擎','大推力引擎','标准燃料舱','扩展燃料舱','基础货舱','大型货舱','回收支架','简化尾舱']
for i,p in enumerate(parts):
 x=54;y=325+i*53
 A += [shape_rect(x,y,274,45,raised,border,5),text(x+15,y+29,'⋮⋮   '+p,15,fg)]
A += [text(397,281,'火箭装配架  /  拖入高亮插槽',19,cyan,700)]
for i,(label,part) in enumerate([('货舱插槽','基础货舱'),('燃料插槽','标准燃料舱'),('发动机插槽','标准引擎'),('回收组件','回收支架')]):
 y=316+i*106
 A += [shape_rect(464,y,455,87,raised,cyan if i==1 else border,7),text(488,y+31,label,14,mute),text(488,y+63,part,20,fg,700)]
A += [panel_title(1064,282,'设计性能预览','当前为 UX 示例数值'),text(1066,350,'载重                 120 t',19,fg),text(1066,402,'航程                 2.4 AU',19,fg),text(1066,454,'复用能力            8 次',19,fg),text(1066,506,'运费估计            800 Cr/趟',19,amber),line(1062,538,1380,538),text(1065,580,'不模拟复杂轨道力学。',15,mute),text(1065,614,'组合应改变实际运输经济。',15,mute),button(1064,706,322,'保存蓝图并返回采矿 →',True)]
close(A,keys[3])
# 05 market
A=shell('矿石交易中心','只展示当前可销售资源、两家买方报价与“卖出／等待”选择',4)
for i,(a,b) in enumerate([('可售矿石','80 t'),('累计交易','0 t'),('累计收入','0 Cr')]):
 x=30+i*464;A += [shape_rect(x,184,448,99,raised,border),text(x+24,219,a,14,mute),text(x+24,264,b,29,green if i==0 else cyan,700)]
A += [shape_rect(30,302,835,472,panel,border),panel_title(55,350,'双买方动态报价','青色：晨曦交易所    金色：赤曜工业联盟'),shape_rect(56,372,783,310,'#0b1c2b',border,5)]
for y in [417,476,535,594,653]:A.append(line(79,y,814,y,border,1,'4 7'))
for col,phase in [(cyan,0),(amber,1.6)]:
 points=[]
 for i in range(55):
  x=79+i*13.4;y=545-70*math.sin(i/8+phase)-25*math.cos(i/3.1+phase)
  points.append(f'{x:.1f},{y:.1f}')
 A.append(f'<polyline points="{" ".join(points)}" fill="none" stroke="{col}" stroke-width="3"/>')
A += [text(55,742,'报价图为 UX 示意；真实行情应来自经济引擎',14,mute)]
for i,(n,sub,price) in enumerate([('晨曦交易所','低价稳定 · 距离近','200 Cr/t'),('赤曜工业联盟','高价波动 · 有配额','240 Cr/t')]):
 x=889;y=302+i*236
 A += [shape_rect(x,y,521,224,raised,border),text(x+25,y+44,n,22,fg,700),text(x+25,y+78,sub,15,mute),text(x+25,y+130,price,29,cyan if i==0 else amber,700),button(x+25,y+160,469,'出售全部可售库存',True)]
close(A,keys[4])
# 06 settle
A=shell('本轮经营结算','通过收入、成本、利润和明确的建议反馈，让玩家产生“再来一轮”的动机',5)
for i,(a,b,col) in enumerate([('本轮收入','19,200 Cr',green),('经营成本','12,100 Cr',amber),('净利润','7,100 Cr',cyan)]):
 x=30+i*464;A += [shape_rect(x,180,448,112,raised,border),text(x+24,220,a,15,mute),text(x+24,265,b,32,col,700)]
A += [shape_rect(30,311,848,500,panel,border),shape_rect(899,311,511,500,raised,border),panel_title(55,360,'本轮回顾  /  晨曦矿区'),line(55,382,847,382)]
rows=[('竞拍矿区','青岚碎星带'),('已勘探天体','1 处'),('已部署采矿设备','1 套'),('火箭往返任务','1 趟'),('累计矿石售出','80 t'),('期末剩余现金','47,100 Cr')]
for i,(a,b) in enumerate(rows):
 y=427+i*60;A += [text(60,y,a,18,mute),text(826,y,b,18,fg,650,'end'),line(60,y+18,822,y+18,border)]
A += [panel_title(925,360,'下一轮投资方向','完整的短局反馈，而不只是数字'),text(925,435,'01  更早扫描高价值矿体',18,fg),text(925,492,'02  根据趟数选择复用火箭',18,fg),text(925,549,'03  在合适的报价时出售',18,fg),text(925,636,'你已经完成第一轮经营！',20,green,700),button(924,715,460,'返回总部 / 开始下一轮  →',True)]
close(A,keys[5])
print('wrote',len(keys),'SVGs and preview PNGs')
