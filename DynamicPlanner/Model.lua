local _, A = ...
local M = {}; A.Model=M
function M.copy(v)
 if type(v)~='table' then return v end
 local out={}; for k,x in pairs(v) do out[k]=M.copy(x) end; return out
end
function M.new(plan,phases) return {plan=M.copy(plan),phases=M.copy(phases),undo={},redo={}} end
function M.transaction(m,fn)
 local before=M.copy(m.plan); fn(m.plan)
 m.undo[#m.undo+1]=before; if #m.undo>100 then table.remove(m.undo,1) end; m.redo={}
end
function M.undo(m)
 if #m.undo==0 then return false end
 m.redo[#m.redo+1]=m.plan; m.plan=table.remove(m.undo); return true
end
function M.redo(m)
 if #m.redo==0 then return false end
 m.undo[#m.undo+1]=m.plan; m.plan=table.remove(m.redo); return true
end
function M.absolute(a,phases)
 for _,p in ipairs(phases) do if tostring(p.id)==tostring(a.phase) then return p.start+a.time end end
 return nil
end
function M.at(t,phases)
 local ph=phases[1]
 for _,p in ipairs(phases) do if p.start<=t then ph=p end end
 return ph,t-ph.start
end
function M.move(a,t,phases)
 local p,offset=M.at(t,phases); a.phase=t<0 and '1' or tostring(p.id); a.time=A.NSRT.round1(offset)
end
function M.snap(t,anchors,tolerance)
 local best,dist=t,tolerance or 3
 for _,a in ipairs(anchors) do if math.abs(a-t)<=dist then best=a;dist=math.abs(a-t) end end
 return best
end
function M.simulate(list,max)
 local out={};max=max or 1
 local have,nextT=max,nil
 for _,x in ipairs(list) do
  local cd=x.cd
  if not cd or cd<=0 then out[x.key]={early=0}
  else
   while nextT and nextT<=x.t+0.05 do have=have+1;nextT=have<max and nextT+cd or nil end
   if have>=1 then have=have-1;if not nextT then nextT=x.t+cd end;out[x.key]={left=max>1 and have or nil,early=0,back=nextT,max=max}
   else out[x.key]={left=0,early=nextT-x.t,back=nextT,max=max} end
  end
 end
 return out
end
local function cdOf(spell) return spell and spell.cooldown or 0 end
function M.recharge(lines,spell,phases,overrides)
 local list={}
 for i,a in ipairs(lines) do if a.spellId==spell.id then
  local t=overrides and overrides[a] or M.absolute(a,phases); if t then list[#list+1]={key=a,t=t,i=i,cd=cdOf(spell)} end
 end end
 table.sort(list,function(a,b) if a.t==b.t then return a.i<b.i end return a.t<b.t end)
 local res=M.simulate(list,spell.charges or 1)
 for _,r in pairs(res) do r.charges=r.left end
 return res
end
local function earlyOf(list,max,target)
 local have,nextT=max,nil
 for _,x in ipairs(list) do
  local cd=x.cd
  if not cd or cd<=0 then if x.key==target then return 0 end
  else
   while nextT and nextT<=x.t+0.05 do have=have+1;nextT=have<max and nextT+cd or nil end
   if have>=1 then have=have-1;if not nextT then nextT=x.t+cd end;if x.key==target then return 0 end
   elseif x.key==target then return nextT-x.t end
  end
 end
 return 0
end
M.earlyOf=earlyOf
local function byT(p,q) return p.t<q.t end
function M.preStart(spell,t,others)
 local cd=cdOf(spell);if cd<=0 then return nil end
 local mx=spell.charges or 1
 local base={};for i,o in ipairs(others) do base[i]={key=o,t=o.t,cd=cd} end
 local n=#base;local probe={key='probe',t=0,cd=cd};local me={key='self',t=t,cd=cd};local L={}
 local function blocked(e)
  for i=1,n do L[i]=base[i] end;probe.t=e;L[n+1]=probe;L[n+2]=me
  table.sort(L,byT)
  return earlyOf(L,mx,'self')>0.05
 end
 local hi=math.max(0,t-0.1);if not blocked(hi) then return nil end
 local lo=math.max(0,t-cd*mx);if blocked(lo) then return lo end
 for _=1,14 do local m=(lo+hi)/2;if blocked(m) then hi=m else lo=m end end
 return hi
end
function M.conflicts(plan,phases,catalog,overrides,only)
 local by,out={}, {}
 for i,a in ipairs(plan.lines) do if a.spellId and catalog[a.spellId] and (not only or only[a.tag..'|'..a.spellId]) then
  local t=overrides and overrides[a] or M.absolute(a,phases)
  if t then local k=a.tag..'|'..a.spellId;by[k]=by[k] or {};by[k][#by[k]+1]={key=a,t=t,i=i,cd=cdOf(catalog[a.spellId])} end
 end end
 for _,list in pairs(by) do
  table.sort(list,function(p,q) if p.t==q.t then return p.i<q.i end return p.t<q.t end)
  local sp=catalog[list[1].key.spellId]
  for line,r in pairs(M.simulate(list,sp.charges or 1)) do if r.early>0.05 then out[line]=r.early end end
 end
 return out
end
function M.problems(plan,phases,catalog,casts)
 local list,conf,unc={},0,0
 for a in pairs(M.conflicts(plan,phases,catalog)) do
  local t=M.absolute(a,phases);if t then conf=conf+1;list[#list+1]={kind='conflict',t=t,line=a} end
 end
 for _,s in ipairs(M.kickSchedule(plan,casts or {},phases)) do
  local bad=s.ready==false
  if s.group then local none=true;for _,gg in ipairs(s.group) do if gg.it then none=false end end;if none then bad=true end end
  if bad then unc=unc+1;list[#list+1]={kind='uncovered',t=s.t} end
 end
 table.sort(list,function(p,q) return p.t<q.t end)
 return {conflicts=conf,uncovered=unc,list=list}
end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function M.overrideKeys(overrides)
 local keys={};for a in pairs(overrides) do if a.spellId then keys[a.tag..'|'..a.spellId]=true end end;return keys
end
function M.movesBad(plan,phases,catalog,overrides)
 local keys={};for a in pairs(overrides) do if a.spellId then keys[a.tag..'|'..a.spellId]=true end end
 local function red(map) local n=0;for a in pairs(map) do if a.spellId and keys[a.tag..'|'..a.spellId] then n=n+1 end end;return n end
 return red(M.conflicts(plan,phases,catalog,overrides,keys))>red(M.conflicts(plan,phases,catalog,nil,keys))
end
M.CV_LEAD=0.5;M.HEAL_RECOVERY=5
local COVER_CATS={raidDamage=true,raidDot=true,healAbsorb=true,raidDebuff=true,tankbuster=true,tankDebuff=true}
local MOVE_CATS={movement=true,spread=true,groupSoak=true}
local REL={raiddr='mitigate',externals='mitigate',heal='recover',raidmob='move',raidutil='boost',defensives='personal',items='personal'}
M.REL=REL
function M.coverable(ab) return (COVER_CATS[ab.category] or MOVE_CATS[ab.category]) and ab.importance~='hidden' and true or false end
function M.isMoveHit(ab) return MOVE_CATS[ab.category] and true or false end
function M.castHit(c) if c['end'] then return c['end'] end;if c.instant or c.synthetic then return c.start end;return c.start,true end
local function nameTokens(tag) local out={};for tok in tag:gmatch('%S+') do if not M.isSelector(tok) then out[#out+1]=tok end end;return out end
function M.coverCds(plan,phases,catalog)
 local bad=M.conflicts(plan,phases,catalog);local roster={}
 for _,p in ipairs(plan.roster or {}) do roster[p.name:lower()]=p end
 local out={}
 for _,a in ipairs(plan.lines) do
  local c=a.spellId and catalog[a.spellId];local rel=c and REL[c.cat]
  local T=rel and M.absolute(a,phases)
  if T then
   local names=nameTokens(a.tag);local bench=false;local who
   for _,n in ipairs(names) do who=roster[n:lower()];if not (who and who.active) then bench=true end end
   out[#out+1]={a=a,c=c,rel=rel,T=T,dur=c.duration,who=who,bench=bench,recharging=bad[a]~=nil,noFixed=c.effect=='stacks'}
  end
 end
 table.sort(out,function(x,y) return x.T<y.T end)
 return out
end
local function counts(x) return not x.bench and not x.recharging and not x.noFixed end
M.cvCounts=counts
local function empty() return {mitigate={},move={},recover={},personal={},personalN=0} end
local function fits(x,move) return x.rel~='boost' and not x.noFixed and (x.rel~='move' or move) end
local function claimed(core,h,T) for _,t in ipairs(core) do if t>h+1e-6 and t<=T+1e-6 then return true end end;return false end
local function anyCounts(l) for _,e in ipairs(l) do if counts(e.x) then return true end end;return false end
function M.coverPoint(cds,core,h,move,personals)
 local res=empty()
 for _,x in ipairs(cds) do if fits(x,move) then
  local how
  if x.rel=='recover' then if x.T>=h-0.05 and x.T<=h+M.HEAL_RECOVERY and not claimed(core,h,x.T) then how='after' end
  elseif x.T<=h+M.CV_LEAD and h<=x.T+(x.dur or 0)+0.05 then how='on' end
  if how then
   if x.rel=='personal' then if counts(x) then res.personalN=res.personalN+1 end;if personals then res.personal[#res.personal+1]={x=x,how=how} end
   else local l=res[x.rel];l[#l+1]={x=x,how=how} end
  end
 end end
 res.state=(anyCounts(res.mitigate) or anyCounts(res.move)) and 'covered' or anyCounts(res.recover) and 'healed' or 'none'
 res.h=h;return res
end
local function union(list)
 table.sort(list,function(p,q) return p[1]<q[1] end);local out={}
 for _,p in ipairs(list) do if p[2]>p[1] then local l=out[#out];if l and p[1]<=l[2] then l[2]=math.max(l[2],p[2]) else out[#out+1]={p[1],p[2]} end end end
 return out
end
function M.coverWindow(cds,s,e,move,personals)
 local res=empty();local mit,heal={}, {}
 for _,x in ipairs(cds) do if fits(x,move) then
  local a0,a1=x.T,x.T+(x.dur or 0);local on=a0<=e and a1>=s;local after=not on and x.rel=='recover' and a0>e and a0<=e+M.HEAL_RECOVERY
  if on or after then
   if x.rel=='personal' then if counts(x) then res.personalN=res.personalN+1 end;if personals then res.personal[#res.personal+1]={x=x,how='on'} end
   else
    local l=res[x.rel];l[#l+1]={x=x,how=on and 'on' or 'after'}
    if counts(x) and on then local t=(x.rel=='recover') and heal or mit;t[#t+1]={math.max(s,a0),math.min(e,a1)} end
   end
  end
 end end
 local covered=0;for _,p in ipairs(union(mit)) do covered=covered+p[2]-p[1] end
 res.covered=covered;res.len=e-s;res.share=covered/math.max(0.001,e-s);res.s=s;res.e=e;res.h=s
 res.state=covered>0 and 'covered' or anyCounts(res.recover) and 'healed' or 'none'
 return res
end
function M.coverage(boss,plan,phases,catalog,opts)
 opts=opts or {}
 local cds=M.coverCds(plan,phases,catalog);local core={}
 for _,ab in ipairs(boss.abilities or {}) do if M.coverable(ab) and ab.importance=='core' then for _,c in ipairs(ab.casts) do core[#core+1]=(M.castHit(c)) end end end
 table.sort(core)
 local hits={}
 for _,ab in ipairs(boss.abilities or {}) do if M.coverable(ab) then
  local move=M.isMoveHit(ab)
  if ab.category=='raidDot' and ab.windows and #ab.windows>0 then
   for _,w in ipairs(ab.windows) do hits[#hits+1]={ab=ab,win=w,t=w.start,e=w['end'],cv=M.coverWindow(cds,w.start,w['end'],move,opts.personals)} end
  else
   for _,c in ipairs(ab.casts) do local h,low=M.castHit(c);hits[#hits+1]={ab=ab,cast=c,t=h,low=low,cv=M.coverPoint(cds,core,h,move,opts.personals)} end
  end
 end end
 for _,hit in ipairs(hits) do if hit.cv.state=='none' and hit.ab.importance=='minor' then hit.cv.state='quiet' end end
 table.sort(hits,function(p,q) return p.t<q.t end)
 return hits,cds
end
local READY={'raiddr','raidmob','heal','externals'}
function M.suggestCover(plan,phases,catalog,hit)
 local move=M.isMoveHit(hit.ab)
 for _,cat in ipairs(READY) do if cat~='raidmob' or move then
  for _,p in ipairs(plan.roster or {}) do if p.active then
   for _,sp in ipairs(A.Cooldowns or {}) do sp=catalog[sp.id] or sp;if sp.cat==cat and not sp.memberOnly and not sp.hidden and M.canCast(p,sp) and sp.effect~='stacks' then
    local t=math.max(0,(cat=='heal') and hit.t or hit.t-1)
    if cat=='heal' or (sp.duration or 0)>=hit.t-t+0.1 then
     local probe={tag=p.name,spellId=sp.id,extra={}};M.move(probe,t,phases)
     plan.lines[#plan.lines+1]=probe
     local ok=M.conflicts(plan,phases,catalog)[probe]==nil
     if ok then local before=0;for _ in pairs(M.conflicts(plan,phases,catalog)) do before=before+1 end;plan.lines[#plan.lines]=nil;local now=0;for _ in pairs(M.conflicts(plan,phases,catalog)) do now=now+1 end;ok=before==now;plan.lines[#plan.lines+1]=probe end
     plan.lines[#plan.lines]=nil
     if ok then return {player=p,spell=sp,t=t} end
    end
   end end
  end end
 end end
 return nil
end
function M.readyEdges(plan,phases,a,catalog,skip)
 local sp=a.spellId and catalog[a.spellId];local cd=cdOf(sp);local out={}
 if cd<=0 then return out end
 for _,o in ipairs(plan.lines) do if o~=a and not (skip and skip[o]) and o.spellId==a.spellId and o.tag==a.tag then
  local t=M.absolute(o,phases);if t then out[#out+1]=A.NSRT.round1(t+cd);out[#out+1]=A.NSRT.round1(t-cd) end
 end end
 return out
end
M.EV_ITEMS={1295247,1234768,6262};M.DEMONIC_HS=452930
local EV_SET={};for _,id in ipairs(M.EV_ITEMS) do EV_SET[id]=true end
M.EV_SET=EV_SET
function M.canCast(player,spell)
 if not spell or spell.hidden or EV_SET[spell.id] then return false end
 if spell.id==M.DEMONIC_HS and player.classToken~='WARLOCK' then return false end
 if spell.class and spell.class~=0 and spell.class~=player.classId then return false end
 if spell.specs then for _,s in ipairs(spell.specs) do if s==player.specId then return true end end; return false end
 return true
end
function M.canTake(from,to,a,catalog)
 if not a.spellId then return true end
 local sp=catalog[a.spellId]
 if sp then return M.canCast(to,sp) end
 return from and to and from.classId~=nil and from.classId==to.classId
end
function M.swap(plan,old,new,catalog)
 old.active,new.active=false,true
 old.group,new.group=new.group,old.group; old.slot,new.slot=new.slot,old.slot
 for _,a in ipairs(plan.lines) do
  if a.tag==old.name and M.canTake(old,new,a,catalog) then a.tag=new.name end
 end
 if plan.railOrder then for i,n in ipairs(plan.railOrder) do if n==old.name then plan.railOrder[i]=new.name elseif n==new.name then plan.railOrder[i]=old.name end end end
end
function M.everyoneMigrate(plan,phases)
 local seen,moved,keep={},0,{}
 for _,a in ipairs(plan.lines) do if a.tag:lower()=='everyone' and a.spellId then local t=M.absolute(a,phases);if t then seen[#seen+1]={a.spellId,t} end end end
 for _,a in ipairs(plan.lines) do
  if a.tag:lower()~='everyone' and a.spellId and EV_SET[a.spellId] and not a.tag:find('%s') then
   local t=M.absolute(a,phases) or 0;moved=moved+1;local dup=false
   for _,s in ipairs(seen) do if s[1]==a.spellId and math.abs(s[2]-t)<=1 then dup=true;break end end
   if not dup then seen[#seen+1]={a.spellId,t};a.tag='everyone';keep[#keep+1]=a end
  else keep[#keep+1]=a end
 end
 plan.lines=keep
 return moved
end
function M.canon(id) return id and A.Aliases and A.Aliases[id] or id end
function M.canonAll(plan) for _,a in ipairs(plan.lines) do a.spellId=M.canon(a.spellId) end end
local ROLE_RANK={tank=1,healer=2,melee=3,ranged=4}
local function slotOf(p) return p.active and p.group and p.slot and (p.group-1)*5+p.slot or 99 end
function M.railOrdered(plan,mode)
 mode=mode or plan.railMode or 'role'
 local all={};for _,p in ipairs(plan.roster or {}) do all[#all+1]=p end
 local at={};for i,n in ipairs(plan.railOrder or {}) do at[n]=i end
 local function cmp(a,b,...)
  for _,f in ipairs({...}) do local x,y=f(a),f(b);if x~=y then return x<y end end
  return a.name:lower()<b.name:lower()
 end
 local role=function(p) return ROLE_RANK[p.role] or 5 end
 local slot=slotOf
 local class=function(p) return p.classToken or 'ZZZ' end
 local custom=function(p) return at[p.name] or 1e6 end
 if mode=='group' then table.sort(all,function(a,b) return cmp(a,b,slot) end)
 elseif mode=='class' then table.sort(all,function(a,b) return cmp(a,b,role,class) end)
 elseif mode=='custom' then table.sort(all,function(a,b) return cmp(a,b,custom,role,slot) end)
 else table.sort(all,function(a,b) return cmp(a,b,role,slot) end) end
 return all
end
function M.railMove(plan,name,before)
 local full={};for _,p in ipairs(M.railOrdered(plan)) do if p.name~=name then full[#full+1]=p.name end end
 local at=#full+1;if before then for i,n in ipairs(full) do if n==before then at=i;break end end end
 table.insert(full,at,name);plan.railMode='custom';plan.railOrder=full
end
function M.setRailMode(plan,mode)
 if mode~='custom' then local o={};for _,p in ipairs(M.railOrdered(plan,mode)) do o[#o+1]=p.name end;plan.railOrder=o end
 plan.railMode=mode
end
local KICK_CLASS={WARRIOR={6552,'Pummel',15},ROGUE={1766,'Kick',15},DEATHKNIGHT={47528,'Mind Freeze',15},DEMONHUNTER={183752,'Disrupt',15},
 MONK={116705,'Spear Hand Strike',15},SHAMAN={57994,'Wind Shear',12},PALADIN={96231,'Rebuke',15},MAGE={2139,'Counterspell',24},
 HUNTER={147362,'Counter Shot',24},WARLOCK={19647,'Spell Lock',24},EVOKER={351338,'Quell',20},DRUID={106839,'Skull Bash',15},PRIEST=false}
local KICK_SPEC={['DRUID|Balance']={78675,'Solar Beam',60},['DRUID|Restoration']=false,['PRIEST|Shadow']={15487,'Silence',45},['HUNTER|Survival']={187707,'Muzzle',15}}
function M.interruptOf(p)
 if not p or not p.classToken then return nil end
 local spec=A.SpecByID and A.SpecByID[p.specId];local k=p.classToken..'|'..(spec and spec.name or '')
 local v;if KICK_SPEC[k]~=nil then v=KICK_SPEC[k] else v=KICK_CLASS[p.classToken] end
 if v==nil then return nil end
 return v and {id=v[1],name=v[2],cd=v[3]} or false
end
local function phaseAt(t,phases) local ph=phases[1];for _,p in ipairs(phases) do if p.start<=t then ph=p end end;return ph end
local function byName(plan,n) for _,p in ipairs(plan.roster or {}) do if p.name==n then return p end end end
function M.kickSchedule(plan,casts,phases,ks)
 ks=ks or plan.kicks or {};local out={}
 if #ks==0 then
  local pt,w=-1e9,0
  for _,c in ipairs(casts) do if c.start-pt>15 then w=0 else w=w+1 end;pt=c.start;out[#out+1]={t=c.start,line=w%2} end
  return out
 end
 local turn,last,guidLine,prevT,inWave={},{},{},-1e9,0
 local guidN=0
 for _,c in ipairs(casts) do
  if c.start-prevT>15 then inWave=0;guidLine={};guidN=0 else inWave=inWave+1 end
  prevT=c.start
  local ph=c.phase or tostring(phaseAt(c.start,phases).id);local live={}
  for i,k in ipairs(ks) do if not k.phase or k.phase=='' or k.phase==ph then live[#live+1]={k=k,i=i} end end
  if #live>0 then
   local li
   if c.guid then if not guidLine[c.guid] then guidLine[c.guid]=guidN;guidN=guidN+1 end;li=guidLine[c.guid]%#live else li=inWave%#live end
   local k,i=live[li+1].k,live[li+1].i
   if #k.players==0 then out[#out+1]={t=c.start,line=i-1,k=k}
   else
    local n=turn[i] or 0;turn[i]=n+1
    local per=math.max(1,math.min(#k.players,math.floor(tonumber(k.per) or 1)))
    local names,seen={},{}
    for j=0,per-1 do local nm=k.players[(n*per+j)%#k.players+1];if not seen[nm] then seen[nm]=true;names[#names+1]=nm end end
    local group={}
    for _,nm in ipairs(names) do
     local it=M.interruptOf(byName(plan,nm));local prev=last[nm]
     local ready;if it==nil or it==false then ready=nil else ready=prev==nil or c.start-prev>=it.cd-0.05 end
     group[#group+1]={player=nm,it=it,prev=prev,ready=ready}
    end
    local taker;for _,g in ipairs(group) do if g.ready==true then taker=g;break end end
    if taker then last[taker.player]=c.start end
    local ready=false;local anyReady,allNil=false,true
    for _,g in ipairs(group) do if g.ready==true then anyReady=true end;if g.ready~=nil then allNil=false end end
    if anyReady then ready=true elseif allNil then ready=nil end
    out[#out+1]={t=c.start,line=i-1,k=k,player=group[1].player,group=group,ready=ready,n=n+1}
   end
  end
 end
 return out
end
function M.kickers(plan)
 local out={};for _,p in ipairs(plan.roster or {}) do if p.active and M.interruptOf(p) then out[#out+1]=p end end
 table.sort(out,function(a,b) local x,y=M.interruptOf(a).cd,M.interruptOf(b).cd;if x~=y then return x<y end;return slotOf(a)<slotOf(b) end)
 return out
end
function M.suggestKicks(plan,casts,phases)
 local pool=M.kickers(plan);if #pool==0 then return nil end
 local lines={{},{}};for i,p in ipairs(pool) do local l=lines[(i-1)%2+1];l[#l+1]=p.name end
 if #lines[2]==0 then lines[2]=nil end
 local mk={};for _,pl in ipairs(lines) do mk[#mk+1]={label='',phase='',players=pl,backups={}} end
 local function late(s) local n=0;for _,x in ipairs(s) do if x.ready==false then n=n+1 end end;return n end
 local sch=M.kickSchedule(plan,casts,phases,mk)
 local all2=true;for _,k in ipairs(mk) do if #k.players<2 then all2=false end end
 if late(sch)>0 and all2 then
  for _,k in ipairs(mk) do k.per=2 end;local s2=M.kickSchedule(plan,casts,phases,mk)
  if late(s2)<late(sch) then sch=s2 else for _,k in ipairs(mk) do k.per=nil end end
 end
 return {kicks=mk,late=late(sch),total=#sch}
end
function M.kicksFromBlocks(plan)
 local block=plan.kickBlocks and plan.kickBlocks[1];if not block then return end
 local ks={}
 for i=2,#block-1 do
  local raw=block[i];local clean=raw:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','');local players,rawPlayers={},{}
  for tok in clean:gmatch('%S+') do
   local nm=tok;for _,p in ipairs(plan.roster or {}) do if p.name:lower()==tok:lower() then nm=p.name end end
   players[#players+1]=nm;rawPlayers[#rawPlayers+1]=nm
  end
  ks[#ks+1]={label='',phase='',players=players,backups={},raw=raw,rawPlayers=rawPlayers}
 end
 plan.kicks=ks;plan.kickBlocks=nil
end
function M.kickLines(plan)
 local ks=plan.kicks;if not ks or #ks==0 then return nil end
 local out={'intstart'}
 for _,k in ipairs(ks) do
  local same=k.raw and k.rawPlayers and #k.rawPlayers==#k.players
  if same then for i,n in ipairs(k.players) do if k.rawPlayers[i]~=n then same=false end end end
  if same then out[#out+1]=k.raw
  else
   local per=math.max(1,math.floor(tonumber(k.per) or 1));local names={}
   if per<2 then for _,n in ipairs(k.players) do names[#names+1]=n end else local n=0;while n*per<#k.players do names[#names+1]=k.players[n*per+1];n=n+1 end end
   for i,n in ipairs(names) do for _,r in ipairs({'US','EU','KR','TW','CN'}) do n=n:gsub('%-[^%-]+%-'..r..'$','') end;names[i]=n end
   out[#out+1]=table.concat(names,' ')
  end
 end
 out[#out+1]='intend'
 return out
end
local selectors={everyone=true,tank=true,healer=true,damager=true,dps=true,melee=true,ranged=true}
function M.isSelector(tag)
 local t=tag:lower()
 return selectors[t] or t:match('^group%d$')~=nil or t:match('^%d+$')~=nil
end
function M.seedRoster(plan,base)
 plan.roster=plan.roster or {}
 if #plan.roster>0 or not base then return end
 local active=0
 for _,p in ipairs(base) do local q=M.copy(p);if q.active and active<20 then active=active+1 else q.active=false end;plan.roster[#plan.roster+1]=q end
end
function M.mergeRoster(plan,base)
 plan.roster=plan.roster or {}
 local kept={}
 for _,p in ipairs(plan.roster) do if not M.isSelector(p.name) then kept[#kept+1]=p end end
 plan.roster=kept
 if not base then return end
 local byName={};for _,p in ipairs(plan.roster) do byName[p.name:lower()]=p end
 for _,b in ipairs(base) do
  local p=byName[b.name:lower()]
  if p then
   for _,k in ipairs({'classId','classToken','specId','role','itemLevel'}) do if p[k]==nil then p[k]=b[k] end end
  elseif #plan.roster<30 then
   local q=M.copy(b);q.active=false;plan.roster[#plan.roster+1]=q;byName[q.name:lower()]=q
  end
 end
 local active=0;for _,p in ipairs(plan.roster) do if p.active then active=active+1 end end
 local byBase={};for _,b in ipairs(base) do byBase[b.name:lower()]=b end
 for _,p in ipairs(plan.roster) do local b=byBase[p.name:lower()];if active<20 and not p.active and b and b.active then p.active=true;active=active+1 end end
 for _,p in ipairs(plan.roster) do if active<20 and not p.active and p.classToken then p.active=true;active=active+1 end end
end
function M.activateTagged(plan)
 local tagged={}
 for _,a in ipairs(plan.lines) do for tag in a.tag:gmatch('%S+') do tagged[tag:lower()]=true end end
 local n=0
 for _,p in ipairs(plan.roster) do local was=p.active;p.wasActive=was;p.active=false;if tagged[p.name:lower()] and n<20 then p.active=true;n=n+1 end end
 for _,p in ipairs(plan.roster) do if not p.active and p.wasActive and n<20 then p.active=true;n=n+1 end;p.wasActive=nil end
end
function M.rosterFromTags(plan)
 plan.roster=plan.roster or {}; local seen={}
 for _,p in ipairs(plan.roster) do seen[p.name:lower()]=true end
 for _,a in ipairs(plan.lines) do for tag in a.tag:gmatch('%S+') do
  if not seen[tag:lower()] and not M.isSelector(tag) then
   local i=#plan.roster; plan.roster[#plan.roster+1]={name=tag,active=i<20,group=math.floor(i/5)+1,slot=i%5+1}
   seen[tag:lower()]=true
  end
 end end
end
function M.seat(plan)
 local occupied={};local pending={}
 for _,p in ipairs(plan.roster) do if p.active then
  local key=p.group and p.slot and (p.group-1)*5+p.slot
  if key and key>=1 and key<=20 and not occupied[key] then occupied[key]=p else pending[#pending+1]=p end
 end end
 for _,p in ipairs(pending) do
  local seat;for i=1,20 do if not occupied[i] then seat=i;break end end
  if seat then p.group=math.floor((seat-1)/5)+1;p.slot=(seat-1)%5+1;occupied[seat]=p else p.active=false end
 end
 return occupied
end
return M
