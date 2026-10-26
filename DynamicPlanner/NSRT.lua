local _, A = ...
local N = {}
A.NSRT = N
local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function number(s, positive)
 if not s or not s:match(positive and '^%d*%.?%d+$' or '^%-?%d*%.?%d+$') then return nil end
 return tonumber(s)
end
local known = {ph=true,time=true,tag=true,spellid=true,text=true}
function N.forEncounter(text,id)
 if type(text)~='string' then return nil end
 local out,active={},false
 for raw in (text:gsub('\r\n','\n'):gsub('\r','\n')..'\n'):gmatch('(.-)\n') do
  local header=raw:match('EncounterID:(%d+)')
  if header then active=tonumber(header)==id end
  if active then out[#out+1]=raw end
 end
 if #out==0 then return nil end
 return table.concat(out,'\n')
end
function N.parse(text)
 if type(text) ~= 'string' then return nil, 'Expected a text note' end
 if #text > 1048576 then return nil, 'Note exceeds 1 MiB' end
 local p = {lines={},rejected={},kickBlocks={},notes={},difficulty='Mythic',terminalNewline=text:sub(-1)=='\n'}
 local kick
 local index = 0
 for raw in (text:gsub('\r\n','\n'):gsub('\r','\n')..'\n'):gmatch('(.-)\n') do
  index=index+1
  local line=trim(raw)
  if kick then
   kick[#kick+1]=raw
   if line:lower()=='intend' then kick=nil end
  elseif line:lower()=='intstart' and p.encounterId then
   kick={raw};p.kickBlocks[#p.kickBlocks+1]=kick
  elseif line~='' and not line:find('EncounterID:',1,true) and (line:lower():match('^assign:') or line:lower():match('^invitelist:') or line:lower():match('^glowunit:') or not (';'..line):find(';%s*time:') and not (';'..line):find(';%s*tag:') and not (';'..line):find(';%s*spellid:')) then
   p.notes[#p.notes+1]=raw
  elseif line~='' then
   local f,extra={},{}
   for key,value in (line..(line:sub(-1)==';' and '' or ';')):gmatch('%s*([%a]+):([^;]*);') do
    if not f[key] then f[key]=value end
    if not known[key] then extra[#extra+1]={key,value} end
   end
   if f.EncounterID then
    local id=tonumber(f.EncounterID)
    if p.encounterId and p.encounterId~=id then return nil,'Multiple encounters: import one boss at a time' end
    p.encounterId=id; p.name=f.Name; p.difficulty=f.Difficulty or 'Mythic'
   else
    local time=number(f.time); local ph=number(f.ph,true) or 1
    local spell=f.spellid and f.spellid:match('^%d+$') and tonumber(f.spellid)
    if spell and A.Model and A.Model.canon then spell=A.Model.canon(spell) end
    local reason=not p.encounterId and 'noHeader' or not time and 'noTime' or
     (not f.tag or trim(f.tag)=='') and 'noTag' or (not spell and f.text==nil) and 'noWhat'
    if reason then p.rejected[#p.rejected+1]={line=index,raw=raw,reason=reason}
    else p.lines[#p.lines+1]={phase=time<0 and '1' or tostring(ph),time=time,tag=trim(f.tag),spellId=spell,text=f.text,extra=extra,order=#p.lines+1} end
   end
  end
 end
 if kick then p.rejected[#p.rejected+1]={line=index,raw='',reason='unterminatedInterruptBlock'} end
 if not p.encounterId then return nil,'Missing EncounterID header' end
 return p
end
function N.round1(n) return math.floor(n*10+0.5)/10 end
local function safe(s)
 s=tostring(s or '')
 assert(not s:find('[;\r\n]'),'NSRT fields cannot contain semicolons or line breaks')
 return s
end
function N.serialize(p, include)
 local lines,sorted,seen={}, {},{}
 lines[1]='EncounterID:'..assert(p.encounterId)..';Difficulty:'..safe(p.difficulty or 'Mythic')..';Name:'..safe(p.name)..';'
 for i,a in ipairs(p.lines) do if not include or include(a) then sorted[#sorted+1]={a=a,i=i} end end
 table.sort(sorted,function(x,y)
  local a,b=x.a,y.a
  if tonumber(a.phase)~=tonumber(b.phase) then return tonumber(a.phase)<tonumber(b.phase) end
  if N.round1(a.time)~=N.round1(b.time) then return N.round1(a.time)<N.round1(b.time) end
  return x.i<y.i
 end)
 for _,it in ipairs(sorted) do
  local a=it.a; local tag=safe(a.tag)
  for _,region in ipairs({'US','EU','KR','TW','CN'}) do tag=tag:gsub('%-[^%-]+%-'..region..'$','') end
  local ph=a.time<0 and '1' or tostring(a.phase or '1')
  local t=string.format('%.1f',N.round1(a.time)); if t=='-0.0' then t='0.0' end
  local what=a.spellId and ('spellid:'..a.spellId..';'..(a.text and a.text~='' and 'text:'..safe(a.text)..';' or '')) or 'text:'..safe(a.text)..';'
  local key=ph..'|'..t..'|'..tag:lower()..'|'..what
  if not seen[key] then
   seen[key]=true
   local s='ph:'..ph..';time:'..t..';tag:'..tag..';'..what
   for _,kv in ipairs(a.extra or {}) do s=s..safe(kv[1])..':'..safe(kv[2])..';' end
   lines[#lines+1]=s
  end
 end
 local kick=A.Model and A.Model.kickLines and A.Model.kickLines(p)
 if kick then for _,line in ipairs(kick) do lines[#lines+1]=line end
 else for _,block in ipairs(p.kickBlocks or {}) do for _,line in ipairs(block) do lines[#lines+1]=line end end end
 for _,line in ipairs(p.notes or {}) do lines[#lines+1]=line end
 return table.concat(lines,'\n')..(p.terminalNewline and '\n' or '')
end
return N
