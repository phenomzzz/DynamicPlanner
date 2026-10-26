local _, A = ...
local AN={};A.Analyzer=AN
AN.MAX_PULLS=30;AN.MAX_SPELLS=60;AN.MAX_RECAP=6
local function pub(v) return v~=nil and A.Public(v) end
local function num(v) if pub(v) and type(v)=='number' then return v end end
local function str(v) if pub(v) and type(v)=='string' and v~='' then return v end end
local function yes(v) return pub(v) and v==true end
local function now() return type(time)=='function' and time() or 0 end
function AN.Short(n) return (tostring(n or ''):gsub('%-.*$','')) end
function AN.Pulls() A.db.pulls=A.db.pulls or {};return A.db.pulls end
function AN.Types() return Enum and Enum.DamageMeterType end
function AN.Available()
 if not C_DamageMeter or not AN.Types() or type(C_DamageMeter.GetAvailableCombatSessions)~='function' then return false,'api' end
 if C_DamageMeter.IsDamageMeterAvailable then
  local ok,av=pcall(C_DamageMeter.IsDamageMeterAvailable);if ok and av==false then return false,'off' end
 end
 return true
end
function AN.SpellName(id,fallback)
 if C_Spell and C_Spell.GetSpellName and id then local ok,n=pcall(C_Spell.GetSpellName,id);if ok and str(n) then return n end end
 if fallback then return fallback end
 local m=AN.Mechanic(nil,id);if m and m.name then return m.name end
 return 'Spell '..tostring(id)
end
local bossIndex={}
local function indexFor(enc)
 local idx=bossIndex[enc];if idx then return idx end
 idx={};bossIndex[enc]=idx
 local boss=A.Bosses and A.Bosses[enc];if not boss then return idx end
 for _,ab in ipairs(boss.abilities or {}) do
  if ab.spellId and not idx[ab.spellId] then idx[ab.spellId]={name=ab.name,category=ab.category,kind=A.Mechanics.byCategory[ab.category]} end
 end
 return idx
end
function AN.Mechanic(enc,id)
 if not id then return nil end
 local cast=A.Mechanics.damageOf[id] or id
 if enc then return indexFor(enc)[cast] end
 for e in pairs(A.Bosses or {}) do local m=indexFor(e)[cast];if m then return m end end
end
local current
function AN.OnStart(enc,name,diff,size)
 current={enc=num(enc),name=str(name),diff=num(diff),size=num(size),t0=GetTime(),at=now()}
end
function AN.OnEnd(enc,name,diff,size,success,units)
 local p=current or {at=now()};current=nil
 p.enc=num(enc) or p.enc;p.name=str(name) or p.name;p.diff=num(diff) or p.diff;p.size=num(size) or p.size
 p.success=num(success)==1;p.clock=p.t0 and (GetTime()-p.t0) or nil;p.t0=nil
 p.boss={}
 if type(units)=='table' and pub(units) then
  for _,u in ipairs(units) do
   if type(u)=='table' then local pct=num(u.remainingHealthPercent);if pct then p.boss[#p.boss+1]={name=str(u.creatureName),pct=pct} end end
  end
 end
 if not p.enc then return end
 AN.pending=p;AN.tries=0;C_Timer.After(1.5,AN.Try)
end
function AN.Try()
 local p=AN.pending;if not p then return end
 if InCombatLockdown() then AN.waiting=true;return end
 AN.waiting=false
 local ok,pull,why=pcall(AN.Snapshot,p)
 if ok and not pull and why=='secret' and (AN.tries or 0)<2 then AN.tries=(AN.tries or 0)+1;C_Timer.After(2,AN.Try);return end
 AN.pending=nil
 if not ok then pull={meter=false,why='error'};for k,v in pairs(p) do pull[k]=v end
 elseif not pull then pull={meter=false,why=why or 'secret'};for k,v in pairs(p) do pull[k]=v end end
 pull.clock=nil
 AN.Store(pull)
end
function AN.Store(pull)
 local list=AN.Pulls()
 A.db.pullSeq=(A.db.pullSeq or 0)+1;pull.id=A.db.pullSeq
 A.db.pullCount=A.db.pullCount or {}
 local key=tostring(pull.enc)..':'..tostring(pull.diff or 0);A.db.pullCount[key]=(A.db.pullCount[key] or 0)+1;pull.n=A.db.pullCount[key]
 table.insert(list,1,pull)
 while #list>AN.MAX_PULLS do table.remove(list) end
 AN.selected=pull.id
 A.Message(A.T('ana.saved',{boss=pull.name or tostring(pull.enc),n=pull.n}))
 if A.UI.AnalyzerChanged then A.UI.AnalyzerChanged() end
 return pull
end
function AN.FindSession(p)
 local ok,list=pcall(C_DamageMeter.GetAvailableCombatSessions)
 if not ok or type(list)~='table' then return nil end
 local best,bestScore
 for _,s in ipairs(list) do
  local id=type(s)=='table' and num(s.sessionID)
  if id then
   local nm,d=str(s.name),num(s.durationSeconds)
   local score=id
   if (nm and p.name and nm==p.name) or (d and p.clock and math.abs(d-p.clock)<=10) then score=score+1e9 end
   if not bestScore or score>bestScore then best,bestScore=s,score end
  end
 end
 if not best then return nil end
 return num(best.sessionID),num(best.durationSeconds),bestScore>=1e9
end
local function session(sid,ty)
 local ok,s=pcall(C_DamageMeter.GetCombatSessionFromID,sid,ty);if ok and type(s)=='table' then return s end
end
local function source(sid,ty,guid)
 if not guid then return nil end
 local ok,s=pcall(C_DamageMeter.GetCombatSessionSourceFromID,sid,ty,guid,nil);if ok and type(s)=='table' then return s end
end
local function list(t) return type(t)=='table' and t or {} end
function AN.Recap(rid)
 if not C_DeathRecap or not rid then return nil end
 local ok,ev=pcall(C_DeathRecap.GetRecapEvents,rid);if not ok or type(ev)~='table' then return nil end
 local okm,maxhp=pcall(C_DeathRecap.GetRecapMaxHealth,rid)
 local out={max=okm and num(maxhp) or nil}
 local last;for _,e in ipairs(ev) do local ts=type(e)=='table' and num(e.timestamp);if ts and (not last or ts>last) then last=ts end end
 for i=1,math.min(#ev,AN.MAX_RECAP) do
  local e=ev[i]
  if type(e)=='table' then
   local ts=num(e.timestamp);local kind=str(e.event)
   local r={id=num(e.spellId),name=str(e.spellName),amt=num(e.amount),over=num(e.overkill),hp=num(e.currentHP),ago=(ts and last) and (last-ts) or nil,env=str(e.environmentalType)}
   if kind=='SWING_DAMAGE' then r.id=88163;r.melee=true end
   if not yes(e.hideCaster) then r.src=str(e.sourceName) end
   out[#out+1]=r
  end
 end
 return out
end
function AN.Snapshot(p)
 local pull={};for k,v in pairs(p) do pull[k]=v end
 pull.players={};pull.spells={};pull.deaths={}
 local okA,why=AN.Available()
 if not okA then pull.meter=false;pull.why=why;pull.dur=p.clock;return pull end
 local sid,dur,matched=AN.FindSession(p)
 if not sid then pull.meter=false;pull.why='nosession';pull.dur=p.clock;return pull end
 pull.meter=true;pull.dur=dur or p.clock;pull.matched=matched
 local T=AN.Types();local secret=0;local idx={}
 local function player(src)
  if type(src)~='table' then return nil end
  if num(src.sourceDisplayType)==2 then return nil end
  local n=str(src.name);if not n then secret=secret+1;return nil end
  local i=idx[n]
  if not i then i=#pull.players+1;idx[n]=i;pull.players[i]={n=n,c=str(src.classFilename) or '',spec=num(src.specIconID),taken=0,avoid=0,ints=0,disp=0} end
  return i,pull.players[i]
 end
 local function guid(src) local g=src.sourceGUID;if pub(g) and type(g)=='string' then return g end end
 local byId={}
 local s=session(sid,T.DamageTaken)
 for _,src in ipairs(list(s and s.combatSources)) do
  local i,pl=player(src)
  if i then
   pl.taken=num(src.totalAmount) or 0
   local d=source(sid,T.DamageTaken,guid(src))
   for _,sp in ipairs(list(d and d.combatSpells)) do
    local id,amt=num(sp.spellID),num(sp.totalAmount)
    if id and amt and amt>0 then
     local e=byId[id]
     if not e then e={id=id,name=AN.SpellName(id),src=str(sp.creatureName),total=0,over=0,hits={}};byId[id]=e;pull.spells[#pull.spells+1]=e end
     e.total=e.total+amt;e.over=e.over+(num(sp.overkillAmount) or 0)
     if yes(sp.isAvoidable) then e.avoid=true end
     if yes(sp.isDeadly) then e.deadly=true end
     e.hits[#e.hits+1]={p=i,a=amt}
    end
   end
  end
 end
 for _,pair in ipairs({{T.AvoidableDamageTaken,'avoid'},{T.Interrupts,'ints'},{T.Dispels,'disp'}}) do
  s=session(sid,pair[1])
  for _,src in ipairs(list(s and s.combatSources)) do local i,pl=player(src);if i then pl[pair[2]]=num(src.totalAmount) or 0 end end
 end
 s=session(sid,T.Deaths)
 for _,src in ipairs(list(s and s.combatSources)) do
  local i=player(src);local rid=num(src.deathRecapID)
  if i and rid and rid~=0 then
   local t=num(src.deathTimeSeconds)
   pull.deaths[#pull.deaths+1]={p=i,t=(t and t>=0) and t or nil,recap=AN.Recap(rid)}
  end
 end
 for _,ty in ipairs({T.HealingDone,T.Absorbs}) do
  s=session(sid,ty)
  for _,src in ipairs(list(s and s.combatSources)) do
   local i,pl=player(src)
   if i then
    local d=source(sid,ty,guid(src))
    for _,sp in ipairs(list(d and d.combatSpells)) do local id=num(sp.spellID);if id then pl.heals=pl.heals or {};pl.heals[#pl.heals+1]=id end end
   end
  end
 end
 if #pull.players==0 and secret>0 then return nil,'secret' end
 table.sort(pull.spells,function(a,b) return a.total>b.total end)
 while #pull.spells>AN.MAX_SPELLS do table.remove(pull.spells) end
 for _,e in ipairs(pull.spells) do table.sort(e.hits,function(a,b) return a.a>b.a end) end
 table.sort(pull.deaths,function(a,b) return (a.t or 1e9)<(b.t or 1e9) end)
 return pull
end
function AN.Get(id)
 for _,p in ipairs(AN.Pulls()) do if p.id==id then return p end end
end
function AN.Selected()
 local p=AN.selected and AN.Get(AN.selected)
 if not p then p=AN.Pulls()[1];AN.selected=p and p.id end
 return p
end
function AN.Delete(id)
 local l=AN.Pulls();for i,p in ipairs(l) do if p.id==id then table.remove(l,i);break end end
 if AN.selected==id then AN.selected=nil end
end
function AN.Clear() A.db.pulls={};AN.selected=nil end
function AN.Recent(pull,n)
 local out={}
 if not pull then return out end
 for _,p in ipairs(AN.Pulls()) do if p.enc==pull.enc and p.diff==pull.diff then out[#out+1]=p;if #out>=(n or 12) then break end end end
 return out
end
function AN.Total(pull,key) local s=0;for _,pl in ipairs(pull.players or {}) do s=s+(pl[key] or 0) end;return s end
function AN.BossPct(pull)
 local lo;for _,b in ipairs(pull.boss or {}) do if not lo or b.pct<lo then lo=b.pct end end;return lo
end
function AN.PhaseAt(enc,t)
 local pm=A.PhaseMaps and A.PhaseMaps[enc];if not pm or not t then return nil end
 local ph;for _,p in ipairs(pm.phases) do if p.start<=t then ph=p end end;return ph
end
local function canon(id) return (A.Aliases and A.Aliases[id]) or id end
function AN.PlanFor(enc)
 if A.boss and A.boss.id==enc and A.model then return A.model.plan end
 local b=A.db.bosses and A.db.bosses[enc];return b and b.plan
end
function AN.Planned(pull)
 local out={};if not pull then return out end
 local plan=AN.PlanFor(pull.enc);local pm=A.PhaseMaps and A.PhaseMaps[pull.enc]
 if not plan or not pm then return out end
 for _,a in ipairs(plan.lines or {}) do
  local cd=a.spellId and A.CD[canon(a.spellId)]
  if cd and cd.type=='raid' then
   local t=A.Model.absolute(a,pm.phases)
   if t then out[#out+1]={t=t,dur=cd.duration or 0,spellId=cd.id,who=a.tag,name=cd.name,after=pull.dur and t>pull.dur or false} end
  end
 end
 table.sort(out,function(x,y) return x.t<y.t end)
 return out
end
function AN.CoverAt(planned,t)
 local out={};if not t then return out end
 for _,c in ipairs(planned) do if t>=c.t and t<=c.t+math.max(c.dur,1) then out[#out+1]=c end end
 return out
end
function AN.Seen(pull,who,spellId)
 local w=tostring(who or ''):lower()
 for _,pl in ipairs(pull.players or {}) do
  if pl.n:lower()==w or AN.Short(pl.n):lower()==w then
   for _,id in ipairs(pl.heals or {}) do if id==spellId or canon(id)==spellId then return true end end
  end
 end
end
function AN.Avoidable(pull)
 local out={}
 for _,e in ipairs(pull.spells or {}) do
  local m=AN.Mechanic(pull.enc,e.id);local kind=m and m.kind
  if e.avoid or kind=='ground' or kind=='area' then out[#out+1]={spell=e,kind=kind or 'avoid'} end
 end
 return out
end
function AN.Findings(pull)
 local out={};if not pull or pull.meter==false then return out end
 local d1=pull.deaths[1]
 if d1 then
  local pl=pull.players[d1.p];local kb=d1.recap and d1.recap[1]
  out[#out+1]={key=kb and 'ana.f.first' or 'ana.f.firstNoKb',vars={who=AN.Short(pl and pl.n),t=d1.t and A.UI.Time(d1.t) or '?',spell=kb and AN.SpellName(kb.id,kb.name) or ''},color='tl-death',t=d1.t}
 end
 local early=0;local cut=pull.dur and pull.dur-15
 for _,d in ipairs(pull.deaths) do if d.t and cut and d.t<cut then early=early+1 end end
 if early>=3 then out[#out+1]={key='ana.f.early',vars={n=early},color='tl-death',view='deaths'} end
 local av=AN.Avoidable(pull)
 if av[1] then
  local e=av[1].spell;local top=e.hits[1] and pull.players[e.hits[1].p]
  out[#out+1]={key='ana.f.avoid',vars={spell=AN.SpellName(e.id,e.name),amt=A.UI.Num(e.total),n=#e.hits,who=AN.Short(top and top.n)},color='major',view='mechanics'}
 end
 local worst,wv
 for _,pl in ipairs(pull.players) do if (pl.avoid or 0)>0 and (not wv or pl.avoid>wv) then worst,wv=pl,pl.avoid end end
 if worst then out[#out+1]={key='ana.f.player',vars={who=AN.Short(worst.n),amt=A.UI.Num(wv)},color='minor',view='mechanics'} end
 local planned=AN.Planned(pull);local uncovered=0
 for _,d in ipairs(pull.deaths) do if d.t and #AN.CoverAt(planned,d.t)==0 then uncovered=uncovered+1 end end
 if #pull.deaths>0 and #planned>0 then out[#out+1]={key='ana.f.cover',vars={n=uncovered,all=#pull.deaths},color=uncovered>0 and 'minor' or 'heal',view='deaths'} end
 local deadly=0;for _,e in ipairs(pull.spells) do if e.deadly then deadly=deadly+1 end end
 if deadly>0 then out[#out+1]={key='ana.f.deadly',vars={n=deadly},color='major',view='damage'} end
 return out
end
AN.MAX_LOG=10
local function i36(s) if s==nil or s=='' then return nil end;return tonumber(s,36) end
local function fields(s,sep) local out={};if s==nil or s=='' then return out end;for x in (s..sep):gmatch('(.-)%'..sep) do out[#out+1]=x end;return out end
local function checksum(s) local n=0;for i=1,#s do n=(n+s:byte(i))%1679616 end;return n end
function AN.DecodeLog(body)
 local pull={src='log',meter=true,players={},spells={},deaths={},casts={},ints={},disps={},raid={},bossHp={},boss={}}
 local names,srcs,secs={}, {}, {}
 for rec in (body..'~'):gmatch('(.-)~') do
  local f=fields(rec,',');local k=f[1]
  if k=='H' then
   pull.enc=i36(f[2]);pull.diff=i36(f[3]);pull.size=i36(f[4]);pull.success=f[5]=='1';pull.dur=(i36(f[6]) or 0)/10
   pull.at=i36(f[7]);pull.endPct=(i36(f[8]) or 0)/10;pull.n=i36(f[9]);pull.name=f[10]
  elseif k=='P' then pull.players[#pull.players+1]={n=f[2] or '?',c=f[3] or '',spec=i36(f[4]),taken=i36(f[5]) or 0,avoid=0,ints=i36(f[6]) or 0,disp=i36(f[7]) or 0}
  elseif k=='S' then
   local e={id=i36(f[2]),srcIdx=i36(f[3]),total=i36(f[4]) or 0,over=i36(f[5]) or 0,hits={}}
   for _,h in ipairs(fields(f[6],'.')) do local x=fields(h,':');local p,a=i36(x[1]),i36(x[2]);if p and a then e.hits[#e.hits+1]={p=p,a=a,c=i36(x[3]) or 1} end end
   if e.id then pull.spells[#pull.spells+1]=e end
  elseif k=='T' then
   local id=i36(f[2]);local list={}
   for _,h in ipairs(fields(f[3],'.')) do local x=fields(h,':');local s,a=i36(x[1]),i36(x[2]);if s and a then list[#list+1]=s;list[#list+1]=a*1000 end end
   if id then secs[id]=list end
  elseif k=='R' then for i,v in ipairs(fields(f[2],'.')) do pull.raid[i]=(i36(v) or 0)*1000 end
  elseif k=='D' then
   local d={t=(i36(f[2]) or 0)/10,p=i36(f[3]),recap={max=i36(f[4])}}
   for _,h in ipairs(fields(f[5],'.')) do
    local x=fields(h,':');local id=i36(x[2])
    d.recap[#d.recap+1]={ago=(i36(x[1]) or 0)/10,id=id,amt=i36(x[3]),over=i36(x[4]),hp=i36(x[5]),srcIdx=i36(x[6]),melee=id==88163 or nil}
   end
   if d.recap.max==0 then d.recap.max=nil end
   if d.p then pull.deaths[#pull.deaths+1]=d end
  elseif k=='C' then local p,id,t=i36(f[2]),i36(f[3]),i36(f[4]);if p and id and t then pull.casts[#pull.casts+1]={p=p,id=id,t=t/10,on=(i36(f[5]) or 0)>0 and i36(f[5]) or nil} end
  elseif k=='I' then local p,t=i36(f[2]),i36(f[3]);if p and t then pull.ints[#pull.ints+1]={p=p,t=t/10,id=i36(f[4])} end
  elseif k=='X' then local p,t=i36(f[2]),i36(f[3]);if p and t then pull.disps[#pull.disps+1]={p=p,t=t/10,id=i36(f[4]),friendly=f[5]=='1'} end
  elseif k=='B' then local v={};for i,x in ipairs(fields(f[3],'.')) do v[i]=x~='' and i36(x)/10 or false end;pull.bossHp[#pull.bossHp+1]={name=f[2],step=2,v=v}
  elseif k=='N' then for i=2,#f do local x=fields(f[i],':');local id=i36(x[1]);if id then names[id]=x[2] end end
  elseif k=='W' then for i=2,#f do srcs[i-1]=f[i] end
  end
 end
 if not pull.enc or not pull.dur or #pull.players==0 then return nil,'bad' end
 local np=#pull.players
 local function okp(p) return p and p>=1 and p<=np end
 for _,e in ipairs(pull.spells) do
  e.name=names[e.id];e.src=srcs[e.srcIdx or 0];e.srcIdx=nil;e.secs=secs[e.id]
  local keep={};for _,h in ipairs(e.hits) do if okp(h.p) then keep[#keep+1]=h end end;e.hits=keep
 end
 for _,d in ipairs(pull.deaths) do for _,r in ipairs(d.recap) do r.name=names[r.id];r.src=srcs[r.srcIdx or 0];r.srcIdx=nil end end
 local function only(list) local keep={};for _,x in ipairs(list) do if okp(x.p) then keep[#keep+1]=x end end;return keep end
 pull.deaths=only(pull.deaths);pull.casts=only(pull.casts);pull.ints=only(pull.ints);pull.disps=only(pull.disps)
 for _,x in ipairs(pull.ints) do x.name=names[x.id] end
 local ends={};for _,b in ipairs(pull.bossHp) do local last;for _,v in ipairs(b.v) do if v then last=v end end;if last then ends[#ends+1]={name=b.name,pct=last} end end
 local alive=0;for _,e in ipairs(ends) do if e.pct>0.05 then alive=alive+1 end end
 if not pull.success then for _,e in ipairs(ends) do if alive==0 or e.pct>0.05 then pull.boss[#pull.boss+1]=e end end end
 if #pull.boss==0 and not pull.success and pull.endPct>0 then pull.boss[1]={pct=pull.endPct} end
 table.sort(pull.spells,function(a,b) return a.total>b.total end)
 while #pull.spells>AN.MAX_SPELLS do table.remove(pull.spells) end
 table.sort(pull.deaths,function(a,b) return a.t<b.t end)
 table.sort(pull.casts,function(a,b) return a.t<b.t end)
 for _,it in ipairs(AN.Avoidable(pull)) do for _,h in ipairs(it.spell.hits) do local pl=pull.players[h.p];pl.avoid=pl.avoid+h.a end end
 return pull
end
function AN.ImportText(text)
 if type(text)~='string' then return {err='ana.imp.empty'} end
 text=text:gsub('^%s+',''):gsub('%s+$','')
 if text=='' then return {err='ana.imp.empty'} end
 local found=0;local res
 local starts={};for at in text:gmatch('()DPL%d+/') do starts[#starts+1]=at end
 if #starts==0 or starts[1]~=1 then return {err='ana.imp.bad'} end
 for si=1,#starts do
  local chunk=text:sub(starts[si],(starts[si+1] or #text+1)-1):gsub('[\r\n]',''):gsub('%s+$','')
  local ver,key,i,n,ck,data=chunk:match('^(DPL%d+)/(%w+)/(%d+)/(%d+)/(%w+)/(.*)$')
  if not ver then return {err='ana.imp.bad'} end
  if ver~='DPL1' then return {err='ana.imp.version'} end
  i,n=tonumber(i),tonumber(n)
  if not i or not n or n<1 or n>50 or i<1 or i>n then return {err='ana.imp.bad'} end
  if checksum(data)~=tonumber(ck,36) then return {err='ana.imp.check',vars={i=i,n=n}} end
  found=found+1
  local part=AN.partial
  if not part or part.key~=key or part.n~=n then part={key=key,n=n,got={},count=0};AN.partial=part end
  if not part.got[i] then part.got[i]=data;part.count=part.count+1 end
  if part.count==part.n then
   AN.partial=nil;res=nil
   for _,p in ipairs(AN.Pulls()) do if p.src=='log' and p.key==key then AN.selected=p.id;res={pull=p,again=true} end end
   if not res then
    local pull,why=AN.DecodeLog(table.concat(part.got))
    if not pull then return {err='ana.imp.'..(why or 'bad')} end
    pull.key=key;res={pull=AN.StoreLog(pull)}
   end
  else res={got=part.count,of=part.n} end
 end
 if found==0 then return {err='ana.imp.bad'} end
 return res
end
function AN.StoreLog(pull)
 local list=AN.Pulls()
 A.db.pullSeq=(A.db.pullSeq or 0)+1;pull.id=A.db.pullSeq
 table.insert(list,1,pull)
 local logs=0
 for i=1,#list do if list[i].src=='log' then logs=logs+1 end end
 for i=#list,1,-1 do if logs<=AN.MAX_LOG then break end;if list[i].src=='log' then table.remove(list,i);logs=logs-1 end end
 while #list>AN.MAX_PULLS do table.remove(list) end
 AN.selected=pull.id
 if A.UI.AnalyzerChanged then A.UI.AnalyzerChanged() end
 return pull
end
local roleOf
function A.SpecRole(id) if not roleOf then roleOf={};for _,x in ipairs(A.Specs or {}) do roleOf[x.id]=x.role end end;return roleOf[id] end
function AN.CastType(id) local cd=A.CD[canon(id)];return cd and cd.type,cd end
AN.PLAN_TOL,AN.PLAN_WINDOW=1,45
function AN.MatchPlan(pull,planned)
 local byPlan,byCast={},{}
 if not pull or pull.src~='log' then return {byPlan=byPlan,byCast=byCast,log=false} end
 local pairs_={}
 for _,x in ipairs(planned or {}) do
  local w=AN.Short(x.who):lower()
  for _,c in ipairs(pull.casts or {}) do
   local pl=pull.players[c.p]
   if pl and AN.Short(pl.n):lower()==w and canon(c.id)==canon(x.spellId) then
    local d=math.abs(c.t-x.t);if d<=AN.PLAN_WINDOW then pairs_[#pairs_+1]={x=x,c=c,d=d} end
   end
  end
 end
 table.sort(pairs_,function(a,b) if a.d~=b.d then return a.d<b.d end;return a.x.t<b.x.t end)
 for _,q in ipairs(pairs_) do if not byPlan[q.x] and not byCast[q.c] then byPlan[q.x]=q.c;byCast[q.c]=q.x end end
 return {byPlan=byPlan,byCast=byCast,log=true}
end
function AN.PlanDelta(x,c) local d=c.t-x.t;if math.abs(d)<=AN.PLAN_TOL then return 'ontime',d end;return d<0 and 'early' or 'late',d end
function AN.InPull(pull,who) local w=AN.Short(who):lower();for _,pl in ipairs(pull.players or {}) do if AN.Short(pl.n):lower()==w then return pl end end end
function AN.Used(pull,who,spellId)
 if pull.src~='log' then return nil end
 local w=tostring(who or ''):lower();local out={}
 local idx;for i,pl in ipairs(pull.players) do if pl.n:lower()==w or AN.Short(pl.n):lower()==w then idx=i end end
 if not idx then return out,false end
 for _,c in ipairs(pull.casts) do if c.p==idx and (c.id==spellId or canon(c.id)==spellId) then out[#out+1]=c.t end end
 return out,true
end
function AN.ActiveAt(pull,t)
 local out={};if pull.src~='log' or not t then return out end
 for _,c in ipairs(pull.casts) do
  local ty,cd=AN.CastType(c.id)
  if ty=='raid' and c.t<=t and t<=c.t+math.max(cd.duration or 0,1) then out[#out+1]={name=cd.name,who=pull.players[c.p] and pull.players[c.p].n,t=c.t,id=cd.id} end
 end
 return out
end
function AN.SavesBefore(pull,d,window)
 local out={};if pull.src~='log' then return out end
 window=window or 60
 for _,c in ipairs(pull.casts) do
  local ty,cd=AN.CastType(c.id)
  if c.t<=d.t and d.t-c.t<=window and ((ty=='personal' and c.p==d.p) or (ty=='external' and c.on==d.p)) then
   out[#out+1]={id=cd.id,name=cd.name,ago=d.t-c.t,by=ty=='external' and pull.players[c.p] and pull.players[c.p].n or nil}
  end
 end
 return out
end
local ev=CreateFrame('Frame')
ev:RegisterEvent('ENCOUNTER_START');ev:RegisterEvent('ENCOUNTER_END');ev:RegisterEvent('PLAYER_REGEN_ENABLED')
ev:SetScript('OnEvent',function(_,event,...)
 if event=='ENCOUNTER_START' then AN.OnStart(...)
 elseif event=='ENCOUNTER_END' then AN.OnEnd(...)
 elseif event=='PLAYER_REGEN_ENABLED' and AN.pending and AN.waiting then C_Timer.After(1,AN.Try) end
end)
AN.events=ev
