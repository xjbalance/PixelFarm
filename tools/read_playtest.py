"""读取本地诊断summary.json；不联网、不改游戏存档。"""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('summary',type=Path);a=p.parse_args()
s=json.loads(a.summary.read_text());t=s.get('lifetime',s)
print(json.dumps({'active_hours':round(t.get('active_s',0)/3600,3),'foreground_hours':round(t.get('foreground_s',0)/3600,3),'paused_hours':round(t.get('paused_s',0)/3600,3),'background_hours':round(t.get('background_s',0)/3600,3),'days':t.get('days_advanced',0),'plants':t.get('plants',0),'fatigue':t.get('fatigue',0),'rescues':t.get('rescues',0),'diamond_sources':t.get('diamonds',{}),'relationship_sources':t.get('relationships',{}),'trial_failures':t.get('trial_failures',0),'trial_retries':t.get('trial_retries',0),'floor_seconds':t.get('floors_s',{}),'milestones_active_seconds':t.get('milestones',{}),'note':'累计本地试玩历史；不同读档分段见playtest.jsonl，不能自动当成单个新档从零时间。'},ensure_ascii=False,indent=2))
