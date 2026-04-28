function om=build_scatterer_map(sm,om,dl,latm,lonm,fm,ef,bm,gm,lm,vm,pm)
if nargin<1||isempty(sm),sm='3gpp_urban_grid_ground_v2.osm';end
if nargin<2||isempty(om),om='3gpp_urban_grid_scatter.osm';end
if nargin<3||isempty(dl),dl='medium';end
if nargin<6||isempty(fm),fm='single';end
if nargin<7||isempty(ef),ef=0;end
if nargin<8||isempty(bm),bm='concrete';end
if nargin<9||isempty(gm),gm='asphalt';end
if nargin<10||isempty(lm),lm='metal';end
if nargin<11||isempty(vm),vm='metal';end
if nargin<12||isempty(pm),pm='wood';end
T=fileread(sm);
T=regexprep(T,'^[ \t]*<tag k="building:material" v="[^"]*"\s*/>\r?\n','','lineanchors');
T=strrep(T,'    <tag k="height" v="20" />',sprintf('    <tag k="height" v="20" />\n    <tag k="building:material" v="%s" />',bm));
T=strrep(T,sprintf('    <tag k="name" v="GROUND_REFLECTOR" />\n    <tag k="height" v="0.2" />'),sprintf('    <tag k="name" v="GROUND_REFLECTOR" />\n    <tag k="height" v="0.2" />\n    <tag k="building:material" v="%s" />',gm));
[nlat,nlon,id2i,mnid,mwid,R,B]=parseMap(T);
I=ints(R,latm,lonm);
switch lower(dl),case 'low',ls=40;vg=38.33;ps=81.125;case 'medium',ls=30;vg=25;ps=20;otherwise,ls=20;vg=15;ps=8;end
P=struct('t',{},'a',{},'o',{},'r',{},'L',{},'W',{},'H',{},'y',{},'m',{});
P=lamps(P,R,B,I,latm,lonm,ls,fm,ef,lm);P=vehs(P,R,B,I,latm,lonm,vg,fm,ef,vm);P=peds(P,R,B,I,latm,lonm,ps,fm,ef,pm);
A=''; nid=mnid+1; wid=mwid+1;
for i=1:numel(P)
 [la,lo]=rect(P(i),latm,lonm); n=nid:(nid+3); nid=nid+4;
 for k=1:4, A=[A,sprintf('  <node id="%d" lat="%.8f" lon="%.8f" />\n',n(k),la(k),lo(k))]; end %#ok<AGROW>
 A=[A,sprintf(['  <way id="%d">\n    <nd ref="%d" />\n    <nd ref="%d" />\n    <nd ref="%d" />\n    <nd ref="%d" />\n    <nd ref="%d" />\n    <tag k="building" v="yes" />\n    <tag k="name" v="SCATTERER_%s_%03d" />\n    <tag k="height" v="%.2f" />\n    <tag k="building:material" v="%s" />\n  </way>\n'],wid,n(1),n(2),n(3),n(4),n(1),upper(P(i).t),i,P(i).H,P(i).m)]; wid=wid+1; %#ok<AGROW>
end
T=strrep(T,'</osm>',[A,'</osm>']); f=fopen(om,'w'); if f<0,error('无法写入文件: %s',om);end; fwrite(f,T,'char'); fclose(f); fprintf('Scatterer map generated: %s | count = %d\n',om,numel(P));
end
function [nlat,nlon,id2i,mnid,mwid,R,B]=parseMap(T)
N=regexp(T,'<node id="(\d+)" lat="([^"]+)" lon="([^"]+)"\s*/>','tokens'); n=numel(N); nlat=zeros(n,1); nlon=zeros(n,1); id2i=containers.Map('KeyType','char','ValueType','double'); mnid=0; W=regexp(T,'<way id="(\d+)">([\s\S]*?)</way>','tokens'); mwid=0; R=struct('a',{},'o',{},'w',{}); B=struct('a',{});
for i=1:n, id2i(N{i}{1})=i; nlat(i)=str2double(N{i}{2}); nlon(i)=str2double(N{i}{3}); mnid=max(mnid,str2double(N{i}{1})); end
for i=1:numel(W)
 mwid=max(mwid,str2double(W{i}{1})); blk=W{i}{2}; rf=regexp(blk,'<nd ref="(\d+)"\s*/>','tokens'); la=[]; lo=[];
 for k=1:numel(rf), s=rf{k}{1}; if isKey(id2i,s), j=id2i(s); la(end+1,1)=nlat(j); lo(end+1,1)=nlon(j); end, end %#ok<AGROW>
 if isempty(la),continue; end
 if contains(blk,'<tag k="highway"'), wt=regexp(blk,'<tag k="width" v="([^"]+)"\s*/>','tokens','once'); if isempty(wt),w=20;else,w=str2double(wt{1});end; if abs(la(end)-la(1))>=abs(lo(end)-lo(1)),o='ns';else,o='ew';end; R(end+1)=struct('a',[la(1),lo(1),la(end),lo(end)],'o',o,'w',w); %#ok<AGROW>
 elseif contains(blk,'<tag k="building" v="yes"') && ~contains(blk,'GROUND_REFLECTOR') && ~contains(blk,'SCATTERER_'), B(end+1)=struct('a',[min(la),max(la),min(lo),max(lo)]); %#ok<AGROW>
 end
end
end
function I=ints(R,latm,lonm)
I=struct('a',{}); for i=1:numel(R), for j=1:numel(R), if strcmp(R(i).o,'ns')&&strcmp(R(j).o,'ew'), hs=max(R(i).w,R(j).w)/2+3; I(end+1)=struct('a',[mean(R(j).a([1,3])),mean(R(i).a([2,4])),hs*latm,hs*lonm]); end, end, end %#ok<AGROW>
end
function P=lamps(P,R,B,I,latm,lonm,s,fm,ef,m)
for i=1:numel(R), r=R(i); off=7.0; mar=r.w/2+4; ph=rand()*s;
 if strcmp(r.o,'ns'), L=(max(r.a([1,3]))-min(r.a([1,3])))/latm; c=mean(r.a([2,4])); xs=(mar+ph):s:(L-mar); for x=xs, a=min(r.a([1,3]))+x*latm; for sd=[-1,1], P=app(P,B,I,latm,lonm,'lamp',a,c+sd*off*lonm,'ns',0.2,0.2,5,fm,ef,m); end, end
 else, L=(max(r.a([2,4]))-min(r.a([2,4])))/lonm; c=mean(r.a([1,3])); xs=(mar+ph):s:(L-mar); for x=xs, o=min(r.a([2,4]))+x*lonm; for sd=[-1,1], P=app(P,B,I,latm,lonm,'lamp',c+sd*off*latm,o,'ew',0.2,0.2,5,fm,ef,m); end, end
 end
end
end
function P=vehs(P,R,B,I,latm,lonm,g,fm,ef,m)
for i=1:numel(R), r=R(i); lc=[-5.25,-1.75,1.75,5.25]; mar=r.w/2+4;
 for q=1:4, off=lc(q); st=rand()*max(g,5);
  if strcmp(r.o,'ns'), L=(max(r.a([1,3]))-min(r.a([1,3])))/latm; c=mean(r.a([2,4]))+off*lonm; x=mar+st; while x<(L-mar), P=app(P,B,I,latm,lonm,'vehicle',min(r.a([1,3]))+x*latm,c,'ns',5,2,1.6,fm,ef,m); x=x+5+max(2,er(g)); end
  else, L=(max(r.a([2,4]))-min(r.a([2,4])))/lonm; c=mean(r.a([1,3]))+off*latm; x=mar+st; while x<(L-mar), P=app(P,B,I,latm,lonm,'vehicle',c,min(r.a([2,4]))+x*lonm,'ew',5,2,1.6,fm,ef,m); x=x+5+max(2,er(g)); end
  end
 end
end
end
function P=peds(P,R,B,I,latm,lonm,s,fm,ef,m)
for i=1:numel(R), r=R(i); off=8.5; mar=r.w/2+4; ph=rand()*s;
 if strcmp(r.o,'ns'), L=(max(r.a([1,3]))-min(r.a([1,3])))/latm; c=mean(r.a([2,4])); xs=(mar+ph):s:(L-mar); for x=xs, a=min(r.a([1,3]))+(x+(rand()-0.5))*latm; j=(rand()-0.5)*0.4*lonm; for sd=[-1,1], P=app(P,B,I,latm,lonm,'pedestrian',a,c+sd*off*lonm+j,'ns',0.3,0.6,1.7,fm,ef,m); end, end
 else, L=(max(r.a([2,4]))-min(r.a([2,4])))/lonm; c=mean(r.a([1,3])); xs=(mar+ph):s:(L-mar); for x=xs, o=min(r.a([2,4]))+(x+(rand()-0.5))*lonm; j=(rand()-0.5)*0.4*latm; for sd=[-1,1], P=app(P,B,I,latm,lonm,'pedestrian',c+sd*off*latm+j,o,'ew',0.3,0.6,1.7,fm,ef,m); end, end
 end
end
end
function P=app(P,B,I,latm,lonm,t,a,o,r,L,W,H,fm,ef,m)
Y=0; if strcmpi(fm,'multi')&&ef>0, z=linspace(-35,35,ef+2); Y=[0,z(2:end-1)]; end
for y=Y, c=struct('t',t,'a',a,'o',o,'r',r,'L',L,'W',W,'H',H,'y',y,'m',m); if ~ob(c,B,latm,lonm)&&~oi(c,I,latm,lonm), P(end+1)=c; end, end %#ok<AGROW>
end
function tf=ob(c,B,latm,lonm)
[la,lo]=rect(c,latm,lonm); a=[min(la),max(la),min(lo),max(lo)]; tf=false; for i=1:numel(B), b=B(i).a; if ~(a(2)<b(1)-latm || a(1)>b(2)+latm || a(4)<b(3)-lonm || a(3)>b(4)+lonm), tf=true; return; end, end
end
function tf=oi(c,I,latm,lonm)
[la,lo]=rect(c,latm,lonm); a=[min(la),max(la),min(lo),max(lo)]; tf=false; for i=1:numel(I), b=I(i).a; if ~(a(2)<b(1)-b(3) || a(1)>b(1)+b(3) || a(4)<b(2)-b(4) || a(3)>b(2)+b(4)), tf=true; return; end, end
end
function [la,lo]=rect(c,latm,lonm)
hL=.5*c.L; hW=.5*c.W; if strcmp(c.r,'ns'), x=[hW,-hW,-hW,hW]; y=[hL,hL,-hL,-hL]; else, x=[hL,hL,-hL,-hL]; y=[hW,-hW,-hW,hW]; end
ag=c.y*pi/180; rx=cos(ag)*x-sin(ag)*y; ry=sin(ag)*x+cos(ag)*y; la=c.a+ry*latm; lo=c.o+rx*lonm;
end
function x=er(m),u=max(rand,1e-6);x=-m*log(u);end
