window.MM = (() => {
  const $ = (s, r=document) => r.querySelector(s);
  const $$ = (s, r=document) => [...r.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
  const q = k => new URLSearchParams(location.search).get(k);
  const fmt = d => new Date(d).toLocaleString('de-DE',{dateStyle:'short',timeStyle:'short'});
  const toast = (msg, type='ok') => { const el=document.createElement('div'); el.textContent=msg; Object.assign(el.style,{position:'fixed',right:'18px',bottom:'18px',zIndex:9999,padding:'12px 16px',borderRadius:'12px',background:type==='error'?'#c84d58':'#0d3d49',color:'#fff',boxShadow:'0 8px 30px rgba(0,0,0,.2)',fontWeight:'700',maxWidth:'420px'}); document.body.appendChild(el); setTimeout(()=>el.remove(),3200); };
  const configuredGuard = () => { if(window.APP_CONFIGURED) return true; toast('Supabase ist noch nicht konfiguriert. Siehe README.md.', 'error'); return false; };
  const textColorFor = color => { const match=/^#([0-9a-f]{6})$/i.exec(color||''); if(!match)return '#173942'; const value=parseInt(match[1],16),r=value>>16,g=(value>>8)&255,b=value&255; return (r*299+g*587+b*114)/1000<145?'#fff':'#173942'; };

  // Gemeinsame SVG-Engine: Karten erhalten Maße aus ihren umgebrochenen Texten.
  function svgLayout(title, branches, nodes, opts={}) {
    // Both views receive the same data, but database row order is not a
    // layout property. Canonical order guarantees an identical mindmap for
    // participants and the moderator's complete view.
    branches=[...branches].sort((a,b)=>Number(a.sort_order)-Number(b.sort_order)||String(a.id).localeCompare(String(b.id)));
    nodes=[...nodes].sort((a,b)=>String(a.id).localeCompare(String(b.id)));
    const allGroups=opts.showGroups!==false, rootPosition=['left','right','top','bottom','center'].includes(opts.rootPosition)?opts.rootPosition:'left', vertical=opts.rootOrientation==='vertical';
    const gap=28,pad=110,nodeStep=286,workspacePad=Math.max(pad,Number(opts.workspacePadding)||320);
    const wrap=(value,max)=>{const words=String(value||'').trim().split(/\s+/).filter(Boolean),lines=[];let line='';const add=word=>{while(word.length>max){if(line){lines.push(line);line=''}lines.push(word.slice(0,max));word=word.slice(max)}if(!line)line=word;else if((line+' '+word).length<=max)line+=' '+word;else{lines.push(line);line=word}};words.forEach(add);if(line)lines.push(line);return lines.length?lines:[''];};
    const measure=(text,type='node')=>{const lines=wrap(text,type==='root'?20:type==='branch'?26:29),longest=Math.max(...lines.map(x=>x.length)),max=type==='root'?460:type==='branch'?240:260,min=type==='root'?240:type==='branch'?170:154;return {lines,w:Math.ceil(Math.min(max,Math.max(min,longest*7.8+(type==='root'?54:34)))),h:Math.max(type==='root'?68:type==='branch'?58:56,lines.length*18+28)};};
    const root=measure(title,'root'),rootBox=vertical?{w:root.h,h:root.w}:root, branchData=branches.map(b=>({...b,m:measure(b.title,'branch')}));
    const children=new Map();nodes.forEach(n=>{const key=n.parent_id?String(n.parent_id):'';if(!children.has(key))children.set(key,[]);children.get(key).push(n)});
    const childOf=n=>children.get(String(n.id))||[], rootsFor=b=>nodes.filter(n=>String(n.branch_id)===String(b.id)&&!n.parent_id), metrics=new Map(nodes.map(n=>[String(n.id),measure(n.text)]));
    const depthOf=n=>childOf(n).length?1+Math.max(...childOf(n).map(depthOf)):0,maxDepth=Math.max(0,...nodes.map(depthOf));
    const positions=new Map(),branchPositions=new Map(),crossCache=new Map();
    const hasPoint=item=>item?.layout_x!==null&&item?.layout_x!==undefined&&item?.layout_y!==null&&item?.layout_y!==undefined&&Number.isFinite(Number(item.layout_x))&&Number.isFinite(Number(item.layout_y));
    const subtreeCross=(n,horizontal)=>{const key=`${horizontal?'h':'v'}:${n.id}`;if(crossCache.has(key))return crossCache.get(key);const own=horizontal?metrics.get(String(n.id)).h:metrics.get(String(n.id)).w,kids=childOf(n),value=kids.length?Math.max(own,kids.reduce((sum,kid)=>sum+subtreeCross(kid,horizontal),0)+gap*(kids.length-1)):own;crossCache.set(key,value);return value;};
    const forestCross=(forest,horizontal)=>forest.length?forest.reduce((sum,n)=>sum+subtreeCross(n,horizontal),0)+gap*(forest.length-1):0;
    const placeTree=(n,depth,primary,start,horizontal,direction)=>{const size=subtreeCross(n,horizontal),cross=start+size/2;positions.set(String(n.id),horizontal?{x:primary+direction*(228+depth*nodeStep),y:cross}:{x:cross,y:primary+direction*(116+depth*238)});let cursor=start;childOf(n).forEach(kid=>{placeTree(kid,depth+1,primary,cursor,horizontal,direction);cursor+=subtreeCross(kid,horizontal)+gap});};
    let W,H,rootPos;
    if(rootPosition==='left'||rootPosition==='right'){
      const lanes=branchData.map(b=>Math.max(b.m.h,forestCross(rootsFor(b),true))+68);H=Math.max(560,pad*2+lanes.reduce((a,b)=>a+b,0));const branchX=pad+rootBox.w+176;W=Math.max(1180,branchX+120+maxDepth*nodeStep+360+pad);let cursor=pad;
      branchData.forEach((b,i)=>{const forest=rootsFor(b),lane=lanes[i],y=cursor+lane/2;branchPositions.set(String(b.id),{x:branchX,y});let treeCursor=cursor+(lane-forestCross(forest,true))/2;forest.forEach(n=>{placeTree(n,0,branchX,treeCursor,true,1);treeCursor+=subtreeCross(n,true)+gap});cursor+=lane});rootPos={x:pad+rootBox.w/2,y:H/2};
      if(rootPosition==='right'){rootPos.x=W-rootPos.x;branchPositions.forEach(p=>p.x=W-p.x);positions.forEach(p=>p.x=W-p.x)}
    } else if(rootPosition==='top'||rootPosition==='bottom') {
      const lanes=branchData.map(b=>Math.max(b.m.w,forestCross(rootsFor(b),false))+68);W=Math.max(920,pad*2+lanes.reduce((a,b)=>a+b,0));const branchY=pad+rootBox.h+154;H=Math.max(660,branchY+110+maxDepth*238+310+pad);let cursor=pad;
      branchData.forEach((b,i)=>{const forest=rootsFor(b),lane=lanes[i],x=cursor+lane/2;branchPositions.set(String(b.id),{x,y:branchY});let treeCursor=cursor+(lane-forestCross(forest,false))/2;forest.forEach(n=>{placeTree(n,0,branchY,treeCursor,false,1);treeCursor+=subtreeCross(n,false)+gap});cursor+=lane});rootPos={x:W/2,y:pad+rootBox.h/2};
      if(rootPosition==='bottom'){rootPos.y=H-rootPos.y;branchPositions.forEach(p=>p.y=H-p.y);positions.forEach(p=>p.y=H-p.y)}
    } else {
      // Compact radial mindmap: the branches grow in soft arcs around the
      // centre. Siblings use small radial rings instead of one long column,
      // keeping the composition dense and organic even with many ideas.
      rootPos={x:0,y:0};const branchCount=Math.max(branchData.length,1),sector=Math.PI*2/branchCount,radius=Math.max(330,rootBox.w/2+190),polar=(distance,angle)=>({x:Math.cos(angle)*distance,y:Math.sin(angle)*distance}),slotCount=count=>Math.min(4,Math.max(2,Math.ceil(Math.sqrt(count||1))));
      branchData.forEach((b,index)=>{const angle=-Math.PI/2+sector*index,bp=polar(radius,angle),forest=rootsFor(b);branchPositions.set(String(b.id),bp);const placeSprig=(n,distance,nodeAngle,depth)=>{positions.set(String(n.id),polar(distance,nodeAngle));const kids=childOf(n),columns=slotCount(kids.length),mid=(columns-1)/2,spread=Math.min(.52,.24+columns*.075);kids.forEach((kid,kidIndex)=>{const ring=Math.floor(kidIndex/columns),slot=kidIndex%columns,childAngle=nodeAngle+(slot-mid)*spread+(ring%2?.018:-.018),childDistance=distance+214+ring*146+(slot%2?11:0);placeSprig(kid,childDistance,childAngle,depth+1)})};const columns=slotCount(forest.length),mid=(columns-1)/2,spread=Math.min(.60,.28+columns*.08);forest.forEach((n,nodeIndex)=>{const ring=Math.floor(nodeIndex/columns),slot=nodeIndex%columns,nodeAngle=angle+(slot-mid)*spread+(ring%2?.022:-.022),distance=radius+222+ring*150+(slot%2?12:0);placeSprig(n,distance,nodeAngle,0)})});
      const items=[{...rootPos,m:rootBox},...branchData.map(b=>({...branchPositions.get(String(b.id)),m:b.m})),...nodes.map(n=>({...positions.get(String(n.id)),m:metrics.get(String(n.id))}))];const bounds=items.reduce((a,item)=>({minX:Math.min(a.minX,item.x-item.m.w/2),maxX:Math.max(a.maxX,item.x+item.m.w/2),minY:Math.min(a.minY,item.y-item.m.h/2),maxY:Math.max(a.maxY,item.y+item.m.h/2)}),{minX:Infinity,maxX:-Infinity,minY:Infinity,maxY:-Infinity}),dx=pad-bounds.minX,dy=pad-bounds.minY;W=Math.max(920,bounds.maxX-bounds.minX+pad*2);H=Math.max(660,bounds.maxY-bounds.minY+pad*2);rootPos.x+=dx;rootPos.y+=dy;branchPositions.forEach(p=>{p.x+=dx;p.y+=dy});positions.forEach(p=>{p.x+=dx;p.y+=dy});
    }
    branchData.forEach(branch=>{const p=branchPositions.get(String(branch.id));if(p&&hasPoint(branch)){p.x=Number(branch.layout_x);p.y=Number(branch.layout_y)}});
    nodes.forEach(node=>{const p=positions.get(String(node.id));if(p&&hasPoint(node)){p.x=Number(node.layout_x);p.y=Number(node.layout_y)}});
    // Keep cards compact, but never let their rectangles touch. The relaxed
    // force pass makes nearby cards glide apart in their natural (usually
    // diagonal) direction instead of snapping one card along a hard axis.
    const nodeCards=nodes.map((node,index)=>({p:positions.get(String(node.id)),m:metrics.get(String(node.id)),movable:true,index})).filter(item=>item.p&&item.m);
    const fixedCards=[{p:rootPos,m:rootBox,movable:false,index:-1},...branchData.map((branch,index)=>({p:branchPositions.get(String(branch.id)),m:branch.m,movable:false,index:-index-2}))].filter(item=>item.p&&item.m);
    const collisionCards=[...nodeCards,...fixedCards], clearance=28;
    nodeCards.forEach(item=>item.home={x:item.p.x,y:item.p.y});
    const separate=(a,b,amount)=>{const dx=b.p.x-a.p.x,dy=b.p.y-a.p.y,nearZero=Math.abs(dx)+Math.abs(dy)<.01,angle=nearZero?(a.index*2.3999632297):(Math.atan2(dy,dx)),nx=nearZero?Math.cos(angle):dx/Math.hypot(dx,dy),ny=nearZero?Math.sin(angle):dy/Math.hypot(dx,dy),both=a.movable&&b.movable,shareA=both?.5:a.movable?1:0,shareB=both?.5:b.movable?1:0;a.p.x-=nx*amount*shareA;a.p.y-=ny*amount*shareA;b.p.x+=nx*amount*shareB;b.p.y+=ny*amount*shareB;};
    for(let pass=0;pass<260;pass++){
      // A gentle spring retains the user's chosen placement after collisions
      // have settled, without pulling cards back into one another.
      if(pass<150)nodeCards.forEach(item=>{item.p.x+=(item.home.x-item.p.x)*.012;item.p.y+=(item.home.y-item.p.y)*.012});
      let collisions=0;
      for(let i=0;i<collisionCards.length;i++)for(let j=i+1;j<collisionCards.length;j++){
        const a=collisionCards[i],b=collisionCards[j];if(!a.movable&&!b.movable)continue;
        const dx=b.p.x-a.p.x,dy=b.p.y-a.p.y,needX=(a.m.w+b.m.w)/2+clearance,needY=(a.m.h+b.m.h)/2+clearance,overlapX=needX-Math.abs(dx),overlapY=needY-Math.abs(dy);
        if(overlapX<=0||overlapY<=0)continue;
        // Move along the line between centres. This has no preferred x/y
        // direction, so a crowded cluster opens up organically.
        const distance=Math.hypot(dx,dy),nx=distance>.01?Math.abs(dx)/distance:Math.SQRT1_2,ny=distance>.01?Math.abs(dy)/distance:Math.SQRT1_2,escape=Math.min(overlapX/Math.max(nx,.08),overlapY/Math.max(ny,.08));
        separate(a,b,escape*(pass<220?.24:1));collisions++;
      }
      if(!collisions&&pass>150)break;
    }
    // The board deliberately keeps free space on every side. Whenever a card
    // is moved beyond the current content, the next render expands the SVG in
    // that direction, so the layout behaves like an open whiteboard rather
    // than a fixed rectangle.
    const visualItems=[{...rootPos,m:rootBox},...branchData.map(branch=>({...branchPositions.get(String(branch.id)),m:branch.m})),...nodes.map(node=>({...positions.get(String(node.id)),m:metrics.get(String(node.id))}))].filter(item=>Number.isFinite(item.x)&&Number.isFinite(item.y)&&item.m);
    const visualBounds=visualItems.reduce((bounds,item)=>({minX:Math.min(bounds.minX,item.x-item.m.w/2),maxX:Math.max(bounds.maxX,item.x+item.m.w/2),minY:Math.min(bounds.minY,item.y-item.m.h/2),maxY:Math.max(bounds.maxY,item.y+item.m.h/2)}),{minX:0,maxX:W,minY:0,maxY:H});
    const viewX=Math.min(-workspacePad,visualBounds.minX-workspacePad),viewY=Math.min(-workspacePad,visualBounds.minY-workspacePad);
    W=Math.max(W-viewX,visualBounds.maxX+workspacePad-viewX);H=Math.max(H-viewY,visualBounds.maxY+workspacePad-viewY);
    const textLines=(m,x,y,fill,size=14,weight=700)=>`<text x="${x}" y="${y-(m.lines.length-1)*9+5}" text-anchor="middle" font-family="Inter,Arial,sans-serif" font-size="${size}" font-weight="${weight}" fill="${fill}">${m.lines.map((line,i)=>`<tspan x="${x}" dy="${i?'18':'0'}">${esc(line)}</tspan>`).join('')}</text>`;
    const card=(p,m,fill,stroke,klass,content,rotate=false,attrs='')=>`<g${klass?` class="${klass}"`:''}${attrs}${rotate?` transform="rotate(-90 ${p.x} ${p.y})"`:''}><rect x="${p.x-m.w/2}" y="${p.y-m.h/2}" width="${m.w}" height="${m.h}" rx="14" fill="${fill}" stroke="${stroke}" stroke-width="2" filter="url(#sh)"/>${content}</g>`;
    // Connections meet card edges, not their centres. This keeps the visual
    // hierarchy calm, particularly when one branch has many contributions.
    const edgePoint=(from,to)=>{const dx=to.x-from.x,dy=to.y-from.y,halfW=Math.max(0,(from.m?.w||0)/2-7),halfH=Math.max(0,(from.m?.h||0)/2-7);if((!halfW&&!halfH)||(!dx&&!dy))return {x:from.x,y:from.y};const ratio=Math.max(halfW?Math.abs(dx)/halfW:0,halfH?Math.abs(dy)/halfH:0),t=ratio?1/ratio:0;return {x:from.x+dx*t,y:from.y+dy*t}};
    // The bend handle stays on its rendered connection and is available on
    // hover, while automatic links take the shortest, least tangled route.
    const curve=(from,to,stroke,width,item,kind)=>{const a=edgePoint(from,to),b=edgePoint(to,from),dx=b.x-a.x,dy=b.y-a.y,hasBend=item?.bend_x!==null&&item?.bend_x!==undefined&&item?.bend_y!==null&&item?.bend_y!==undefined&&Number.isFinite(Number(item.bend_x))&&Number.isFinite(Number(item.bend_y)),bend=hasBend?{x:Number(item.bend_x),y:Number(item.bend_y)}:{x:(a.x+b.x)/2,y:(a.y+b.y)/2},path=hasBend?`M ${a.x} ${a.y} Q ${(a.x+bend.x)/2} ${(a.y+bend.y)/2}, ${bend.x} ${bend.y} Q ${(bend.x+b.x)/2} ${(bend.y+b.y)/2}, ${b.x} ${b.y}`:`M ${a.x} ${a.y} C ${a.x+dx*.34} ${a.y+dy*.34}, ${b.x-dx*.34} ${b.y-dy*.34}, ${b.x} ${b.y}`,handle=opts.editable&&item?`<circle class="line-handle" data-layout-kind="${kind}" data-layout-id="${esc(item.id)}" cx="${bend.x}" cy="${bend.y}" r="9"/>`:'';return `<g class="mind-connection mind-connection--${kind}"><path d="${path}" fill="none" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round"/>${handle}</g>`;};
    let svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="${viewX} ${viewY} ${W} ${H}"><defs><filter id="sh"><feDropShadow dx="0" dy="3" stdDeviation="4" flood-opacity=".12"/></filter></defs><rect x="${viewX}" y="${viewY}" width="${W}" height="${H}" fill="#fbfefe"/>`;
    const rootCard={...rootPos,m:rootBox};
    branchData.forEach(b=>{const bp={...branchPositions.get(String(b.id)),m:b.m};svg+=curve(rootCard,bp,'#45c6cd',4,b,'branch');rootsFor(b).forEach(n=>{const p={...positions.get(String(n.id)),m:metrics.get(String(n.id))};if(p)svg+=curve(bp,p,'#9ac7cd',3,n,'node')})});nodes.forEach(n=>{if(n.parent_id){const p={...positions.get(String(n.id)),m:metrics.get(String(n.id))},parent={...positions.get(String(n.parent_id)),m:metrics.get(String(n.parent_id))};if(p&&parent)svg+=curve(parent,p,'#b9ced2',2.5,n,'node')}});
    branchData.forEach(b=>{const p=branchPositions.get(String(b.id)),color=/^#[0-9a-f]{6}$/i.test(b.color||'')?b.color:'#eef8c9';svg+=card(p,b.m,color,'#45c6cd','mind-branch',textLines(b.m,p.x,p.y,'#23434b',16,800),false,opts.editable?` data-layout-kind="branch" data-layout-id="${esc(b.id)}" style="cursor:grab"`:'')});
    nodes.forEach(n=>{const p=positions.get(String(n.id)),m=metrics.get(String(n.id)),branch=branchData.find(item=>String(item.id)===String(n.branch_id)),fill=/^#[0-9a-f]{6}$/i.test(branch?.color||'')?branch.color:'#fff',textColor=textColorFor(fill);if(!p)return;let content=textLines(m,p.x,p.y,textColor);if(allGroups&&n.group_no!==null&&n.group_no!==undefined){const isMerged=Number(n.group_no)===0&&/\s·\s*aus\s+G\d/i.test(String(n.text||'')),label=Number(n.group_no)===0?(isMerged?'M':'R'):`G${esc(n.group_no)}`,labelFill=isMerged?'#1f7f8b':'#7162e7';content+=`<rect x="${p.x+m.w/2-42}" y="${p.y-m.h/2+7}" rx="8" width="35" height="21" fill="${labelFill}"/><text x="${p.x+m.w/2-24.5}" y="${p.y-m.h/2+22}" text-anchor="middle" font-family="Inter,Arial" font-size="11" font-weight="900" fill="#fff">${label}</text>`};svg+=card(p,m,fill,'#cfe1e5','mind-node',content,false,` data-node-id="${esc(n.id)}" data-branch-id="${esc(n.branch_id)}" data-layout-kind="node" data-layout-id="${esc(n.id)}" style="cursor:${opts.editable?'grab':'pointer'}"`)});
    return svg+card(rootPos,root,'#0d3d49','#145563','mind-root',textLines(root,rootPos.x,rootPos.y,'#fff',18,900),vertical)+'</svg>';
  }

  // During a drag, reveal more of the otherwise open canvas before the card
  // reaches an edge. A fresh svgLayout() computes tight content bounds again,
  // so unused space disappears on drop, delete, or the next live refresh.
  function growWorkspace(svg, box, padding=260, trigger=130) {
    if(!svg?.viewBox?.baseVal||!box)return false;
    const view=svg.viewBox.baseVal,left=box.x-box.w/2,right=box.x+box.w/2,top=box.y-box.h/2,bottom=box.y+box.h/2;
    let x=view.x,y=view.y,w=view.width,h=view.height,changed=false;
    if(left<x+trigger){const next=left-padding;w+=x-next;x=next;changed=true}
    if(right>x+w-trigger){w=right+padding-x;changed=true}
    if(top<y+trigger){const next=top-padding;h+=y-next;y=next;changed=true}
    if(bottom>y+h-trigger){h=bottom+padding-y;changed=true}
    if(!changed)return false;
    svg.setAttribute('viewBox',`${x} ${y} ${w} ${h}`);svg.setAttribute('width',w);svg.setAttribute('height',h);
    if(svg.dataset.baseWidth!==undefined){svg.dataset.baseWidth=w;svg.dataset.baseHeight=h}
    svg.dispatchEvent(new CustomEvent('mmworkspacegrow',{bubbles:true}));
    return true;
  }

  function downloadBlob(blob,name){const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=name;document.body.appendChild(a);a.click();setTimeout(()=>{URL.revokeObjectURL(a.href);a.remove()},1200)}
  function exportableSvg(svgEl){const clone=svgEl.cloneNode(true);clone.querySelectorAll('.line-handle').forEach(handle=>handle.remove());return clone;}
  function exportSVG(svgEl, name='mindmap.svg'){ const xml=new XMLSerializer().serializeToString(exportableSvg(svgEl)); downloadBlob(new Blob([xml],{type:'image/svg+xml;charset=utf-8'}),name); }
  async function svgToCanvas(svgEl, scale=2){const xml=new XMLSerializer().serializeToString(svgEl), blob=new Blob([xml],{type:'image/svg+xml'}), url=URL.createObjectURL(blob), img=new Image();await new Promise((res,rej)=>{img.onload=res;img.onerror=rej;img.src=url});const c=document.createElement('canvas');c.width=svgEl.viewBox.baseVal.width*scale;c.height=svgEl.viewBox.baseVal.height*scale;const ctx=c.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(img,0,0,c.width,c.height);URL.revokeObjectURL(url);return c;}
  async function exportJPG(svgEl,name='mindmap.jpg'){const c=await svgToCanvas(exportableSvg(svgEl),2);c.toBlob(b=>downloadBlob(b,name),'image/jpeg',.94)}
  async function exportPDF(svgEl,name='mindmap.pdf'){if(!window.jspdf){toast('PDF-Bibliothek konnte nicht geladen werden.','error');return}const c=await svgToCanvas(exportableSvg(svgEl),1.7),img=c.toDataURL('image/jpeg',.93);const {jsPDF}=window.jspdf;const landscape=c.width>=c.height;const pdf=new jsPDF({orientation:landscape?'landscape':'portrait',unit:'pt',format:'a4'});const pw=pdf.internal.pageSize.getWidth(),ph=pdf.internal.pageSize.getHeight(),r=Math.min((pw-36)/c.width,(ph-36)/c.height);pdf.addImage(img,'JPEG',18,18,c.width*r,c.height*r);pdf.save(name)}
  return {$,$$,esc,q,fmt,toast,configuredGuard,svgLayout,growWorkspace,exportSVG,exportJPG,exportPDF,downloadBlob,textColorFor};
})();
